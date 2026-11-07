import 'dart:io';

import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('una base vieja gana columnas de casa sin perder clientes', () async {
    final folder = Directory.systemTemp.createTempSync('dale_u_house');
    addTearDown(() => folder.deleteSync(recursive: true));
    final path = p.join(folder.path, 'dale_u.db');

    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
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
              amount_cents INTEGER NOT NULL,
              occurred_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              pending_sync INTEGER NOT NULL DEFAULT 1,
              voided INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );
    await old.insert('clients', {
      'id': 'c1',
      'vendor_uid': 'uid123',
      'name': 'Doña María',
      'phone': '',
      'created_at': 1000,
      'updated_at': 1000,
      'pending_sync': 0,
      'active': 1,
      'invite_code': 'ABC234',
      'linked_uid': '',
    });
    await old.close();

    final app = await AppDatabase.openWith(databaseFactoryFfi, path);
    final columns = await app.db.rawQuery('PRAGMA table_info(clients)');
    final names = columns.map((column) => column['name']).toList();
    expect(names, containsAll(['latitude', 'longitude']));

    final rows = await app.db.query('clients');
    expect(rows.single['name'], 'Doña María');
    expect(rows.single['latitude'], isNull);
    expect(rows.single['longitude'], isNull);

    final tables = await app.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='pan_orders'",
    );
    expect(tables, isNotEmpty);

    await app.db.close();
  });

  test('guardar la casa en SQLite no borra el nombre', () async {
    final app = await AppDatabase.openWith(
      databaseFactoryFfi,
      inMemoryDatabasePath,
    );
    addTearDown(() => app.db.close());
    final local = ClientLocalDataSource(app);
    final client = await local.insert(
      vendorUid: 'uid123',
      name: 'Doña María',
      phone: '',
    );

    final marked = await local.updateHouse(
      vendorUid: 'uid123',
      id: client.id,
      latitude: -12.05,
      longitude: -77.04,
    );

    expect(marked.name, 'Doña María');
    expect(marked.hasHousePin, isTrue);

    final listed = await local.listByVendor('uid123');
    expect(listed.single.latitude, -12.05);
    expect(listed.single.longitude, -77.04);
  });
}
