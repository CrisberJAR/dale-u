import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:dale_u/features/client/data/sync/stale_client_purger.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/orders/data/pan_order_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryRemote implements ClientRemoteDataSource {
  final deleted = <String>[];
  bool fail = false;

  @override
  Future<void> upsert(Client client) async {}

  @override
  Future<List<Client>> fetchByVendor(String vendorUid) async => const [];

  @override
  Future<void> publishVendorName(String vendorUid) async {}

  @override
  Future<void> deleteCascade({
    required String vendorUid,
    required String clientId,
    required String inviteCode,
  }) async {
    if (fail) throw Exception('offline');
    deleted.add(clientId);
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<AppDatabase> openDb() async {
    final app = await AppDatabase.openWith(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    addTearDown(() => app.db.close());
    return app;
  }

  test('borra local y nube si lleva un mes desactivado sin movimientos', () async {
    final db = await openDb();
    final clients = ClientLocalDataSource(db);
    final movements = MovementLocalDataSource(db);
    final orders = PanOrderLocalDataSource(db);
    await db.db.insert('clients', {
      'id': 'client-001',
      'vendor_uid': 'uid123',
      'name': 'Doña María',
      'phone': '',
      'created_at': DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      'pending_sync': 0,
      'active': 0,
      'invite_code': 'ABC234',
      'linked_uid': '',
    });
    await orders.insert(
      vendorUid: 'uid123',
      label: 'la vecina de la esquina, 2 bolsas',
      deliveryDateKey: 20260831,
    );
    final remote = _MemoryRemote();
    final purger = StaleClientPurger(
      clients: clients,
      movements: movements,
      orders: orders,
      remote: remote,
      now: () => DateTime.utc(2026, 8, 31),
    );

    expect(await purger.run('uid123'), 1);
    expect(remote.deleted, ['client-001']);
    expect(await db.db.query('clients'), isEmpty);
    expect(await db.db.query('pan_orders'), hasLength(1));
  });

  test('si no hay señal no borra el teléfono', () async {
    final db = await openDb();
    final clients = ClientLocalDataSource(db);
    await db.db.insert('clients', {
      'id': 'client-001',
      'vendor_uid': 'uid123',
      'name': 'Doña María',
      'phone': '',
      'created_at': DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      'pending_sync': 0,
      'active': 0,
      'invite_code': 'ABC234',
      'linked_uid': '',
    });
    final remote = _MemoryRemote()..fail = true;
    final purger = StaleClientPurger(
      clients: clients,
      movements: MovementLocalDataSource(db),
      orders: PanOrderLocalDataSource(db),
      remote: remote,
      now: () => DateTime.utc(2026, 8, 31),
    );

    expect(await purger.run('uid123'), 0);
    expect(await db.db.query('clients'), hasLength(1));
  });

  test('un fiado reciente evita borrar', () async {
    final db = await openDb();
    final clients = ClientLocalDataSource(db);
    final movements = MovementLocalDataSource(db);
    await db.db.insert('clients', {
      'id': 'client-001',
      'vendor_uid': 'uid123',
      'name': 'Doña María',
      'phone': '',
      'created_at': DateTime.utc(2026, 6, 1).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 7, 1).millisecondsSinceEpoch,
      'pending_sync': 0,
      'active': 0,
      'invite_code': 'ABC234',
      'linked_uid': '',
    });
    await movements.insert(
      vendorUid: 'uid123',
      clientId: 'client-001',
      kind: MovementKind.fiado,
      amountCents: 500,
      occurredAt: DateTime.utc(2026, 8, 20),
    );
    final remote = _MemoryRemote();
    final purger = StaleClientPurger(
      clients: clients,
      movements: movements,
      orders: PanOrderLocalDataSource(db),
      remote: remote,
      now: () => DateTime.utc(2026, 8, 31),
    );

    expect(await purger.run('uid123'), 0);
    expect(remote.deleted, isEmpty);
    expect(await db.db.query('clients'), hasLength(1));
  });
}
