import 'package:dale_u/features/client/domain/invite_code.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite local (equivalente Flutter de Room). Sin red.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const schemaVersion = 7;

  static Future<AppDatabase> open() async {
    final filePath = p.join(await getDatabasesPath(), 'dale_u.db');
    return openWith(databaseFactory, filePath);
  }

  /// Los tests abren la misma base con otro motor para probar migraciones.
  static Future<AppDatabase> openWith(
    DatabaseFactory factory,
    String path,
  ) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    final app = AppDatabase(database);
    await app.backfillInviteCodes();
    return app;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createClients(db, withActive: true, withInvite: true);
    await _createMovements(db, withVoided: true);
    await _createPanOrders(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createMovements(db, withVoided: false);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE clients ADD COLUMN active INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE movements ADD COLUMN voided INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE clients ADD COLUMN invite_code TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE clients ADD COLUMN linked_uid TEXT NOT NULL DEFAULT ''",
      );
      await _createInviteIndex(db);
    }
    if (oldVersion < 5) {
      await _moveMoneyToCents(db);
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE clients ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE clients ADD COLUMN longitude REAL');
    }
    if (oldVersion < 7) {
      await _createPanOrders(db);
    }
  }

  Future<void> backfillInviteCodes() async {
    final used = <String>{};
    final existing = await db.query('clients', columns: ['invite_code']);
    for (final row in existing) {
      final code = row['invite_code'] as String? ?? '';
      if (code.isNotEmpty) used.add(code);
    }

    final rows = await db.query('clients', columns: ['id', 'invite_code']);
    for (final row in rows) {
      final current = row['invite_code'] as String? ?? '';
      if (current.isNotEmpty) continue;
      var code = InviteCode.generate();
      while (used.contains(code)) {
        code = InviteCode.generate();
      }
      used.add(code);
      await db.update(
        'clients',
        {
          'invite_code': code,
          'pending_sync': 1,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  static Future<void> _createClients(
    Database db, {
    required bool withActive,
    required bool withInvite,
  }) async {
    final extra = StringBuffer();
    if (withActive) {
      extra.write(',\n        active INTEGER NOT NULL DEFAULT 1');
    }
    if (withInvite) {
      extra.write(",\n        invite_code TEXT NOT NULL DEFAULT ''");
      extra.write(",\n        linked_uid TEXT NOT NULL DEFAULT ''");
    }
    extra.write(',\n        latitude REAL');
    extra.write(',\n        longitude REAL');
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY NOT NULL,
        vendor_uid TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1$extra
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_clients_vendor ON clients(vendor_uid)',
    );
    if (withInvite) {
      await _createInviteIndex(db);
    }
  }

  static Future<void> _createInviteIndex(Database db) async {
    await db.execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_clients_invite "
      "ON clients(invite_code) WHERE invite_code != ''",
    );
  }

  static Future<void> _createMovements(
    Database db, {
    required bool withVoided,
  }) async {
    final voidedCol = withVoided
        ? ',\n        voided INTEGER NOT NULL DEFAULT 0'
        : '';
    await db.execute('''
      CREATE TABLE movements (
        id TEXT PRIMARY KEY NOT NULL,
        vendor_uid TEXT NOT NULL,
        client_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1$voidedCol
      )
    ''');
    await _createMovementIndexes(db);
  }

  /// Pedidos locales del vendedor. Al marcar entregado se borra la fila.
  static Future<void> _createPanOrders(Database db) async {
    await db.execute('''
      CREATE TABLE pan_orders (
        id TEXT PRIMARY KEY NOT NULL,
        vendor_uid TEXT NOT NULL,
        client_id TEXT NOT NULL,
        client_name TEXT NOT NULL,
        delivery_date INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_pan_orders_vendor '
      'ON pan_orders(vendor_uid, delivery_date)',
    );
  }

  static Future<void> _createMovementIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movements_vendor '
      'ON movements(vendor_uid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movements_client '
      'ON movements(client_id)',
    );
  }

  /// Los montos pasan de soles enteros a céntimos: 5.000 soles son 500000.
  /// Quedan pendientes de subir para que la nube también se corrija.
  static Future<void> _moveMoneyToCents(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(movements)');
    final inSoles = columns.any((column) => column['name'] == 'amount_pesos');
    if (!inSoles) return;

    await db.execute('''
      CREATE TABLE movements_cents (
        id TEXT PRIMARY KEY NOT NULL,
        vendor_uid TEXT NOT NULL,
        client_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        pending_sync INTEGER NOT NULL DEFAULT 1,
        voided INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      INSERT INTO movements_cents (
        id, vendor_uid, client_id, kind, amount_cents,
        occurred_at, created_at, pending_sync, voided
      )
      SELECT id, vendor_uid, client_id, kind, amount_pesos * 100,
        occurred_at, created_at, 1, voided
      FROM movements
    ''');
    await db.execute('DROP TABLE movements');
    await db.execute('ALTER TABLE movements_cents RENAME TO movements');
    await _createMovementIndexes(db);
  }
}
