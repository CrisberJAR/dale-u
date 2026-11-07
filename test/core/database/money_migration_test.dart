import 'dart:io';

import 'package:dale_u/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// La versión 5 pasa los montos de soles enteros a céntimos.
/// Si esto se rompe, el historial del vendedor se ve cien veces más chico.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<Database> openOldDatabase(String path) {
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE clients (
              id TEXT PRIMARY KEY NOT NULL,
              vendor_uid TEXT NOT NULL,
              name TEXT NOT NULL,
              phone TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              pending_sync INTEGER NOT NULL DEFAULT 1,
              active INTEGER NOT NULL DEFAULT 1,
              invite_code TEXT NOT NULL DEFAULT '',
              linked_uid TEXT NOT NULL DEFAULT ''
            )
          ''');
          await db.execute('''
            CREATE TABLE movements (
              id TEXT PRIMARY KEY NOT NULL,
              vendor_uid TEXT NOT NULL,
              client_id TEXT NOT NULL,
              kind TEXT NOT NULL,
              amount_pesos INTEGER NOT NULL,
              occurred_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              pending_sync INTEGER NOT NULL DEFAULT 1,
              voided INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
  }

  test('los montos viejos en soles pasan a céntimos sin perder nada', () async {
    final folder = Directory.systemTemp.createTempSync('dale_u_test');
    addTearDown(() => folder.deleteSync(recursive: true));
    final path = p.join(folder.path, 'dale_u.db');

    final old = await openOldDatabase(path);
    await old.insert('movements', {
      'id': 'mv1',
      'vendor_uid': 'uid123',
      'client_id': 'c1',
      'kind': 'fiado',
      'amount_pesos': 5000,
      'occurred_at': 1000,
      'created_at': 1000,
      'pending_sync': 0,
      'voided': 0,
    });
    await old.insert('movements', {
      'id': 'mv2',
      'vendor_uid': 'uid123',
      'client_id': 'c1',
      'kind': 'pago',
      'amount_pesos': 20,
      'occurred_at': 2000,
      'created_at': 2000,
      'pending_sync': 0,
      'voided': 1,
    });
    await old.close();

    final app = await AppDatabase.openWith(databaseFactoryFfi, path);
    final rows = await app.db.query('movements', orderBy: 'occurred_at');

    expect(rows.length, 2);
    expect(rows[0]['amount_cents'], 500000);
    expect(rows[0]['kind'], 'fiado');
    expect(rows[1]['amount_cents'], 2000);
    expect(rows[1]['voided'], 1);

    // Quedan pendientes para que la nube también se corrija sola.
    expect(rows.every((row) => row['pending_sync'] == 1), isTrue);

    await app.db.close();
  });

  test('una instalación nueva ya nace en céntimos', () async {
    final app = await AppDatabase.openWith(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    final columns = await app.db.rawQuery('PRAGMA table_info(movements)');
    final names = columns.map((column) => column['name']).toList();

    expect(names, contains('amount_cents'));
    expect(names, isNot(contains('amount_pesos')));

    await app.db.close();
  });
}
