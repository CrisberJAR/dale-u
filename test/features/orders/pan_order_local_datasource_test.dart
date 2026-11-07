import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/error/order_exception.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/orders/data/pan_order_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('anota un recordatorio y al Listo desaparece de SQLite', () async {
    final db = await openDb();
    final local = PanOrderLocalDataSource(db);
    final created = await local.insert(
      vendorUid: 'uid123',
      label: 'la vecina de la esquina, 2 bolsas',
      deliveryDateKey: peruTomorrowDateKey(DateTime.utc(2026, 8, 31, 12)),
    );

    final pending = await local.listPending('uid123');
    expect(pending, hasLength(1));
    expect(pending.single.label, 'la vecina de la esquina, 2 bolsas');

    await local.complete(vendorUid: 'uid123', id: created.id);

    expect(await local.listPending('uid123'), isEmpty);
    final rows = await db.db.query('pan_orders');
    expect(rows, isEmpty);
  });

  test('sin texto no guarda el recordatorio', () async {
    final db = await openDb();
    final local = PanOrderLocalDataSource(db);
    await expectLater(
      local.insert(
        vendorUid: 'uid123',
        label: ' ',
        deliveryDateKey: 20260901,
      ),
      throwsA(isA<OrderException>()),
    );
  });
}
