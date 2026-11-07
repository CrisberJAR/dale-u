import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
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

  test('el cuadre local solo cuenta el día pedido', () async {
    final db = await openDb();
    final local = MovementLocalDataSource(db);
    await local.insert(
      vendorUid: 'uid123',
      clientId: 'client-aa',
      kind: MovementKind.fiado,
      amountCents: 1500,
      occurredAt: fromPeruWallClock(DateTime(2026, 9, 2, 10)),
    );
    await local.insert(
      vendorUid: 'uid123',
      clientId: 'client-aa',
      kind: MovementKind.pago,
      amountCents: 500,
      occurredAt: fromPeruWallClock(DateTime(2026, 9, 2, 16)),
    );
    await local.insert(
      vendorUid: 'uid123',
      clientId: 'client-aa',
      kind: MovementKind.fiado,
      amountCents: 9000,
      occurredAt: fromPeruWallClock(DateTime(2026, 9, 1, 22)),
    );

    final bounds = peruDayBounds(20260902);
    final day = await local.listByDay(
      vendorUid: 'uid123',
      start: bounds.start,
      end: bounds.end,
    );
    expect(day, hasLength(2));
    expect(day.map((item) => item.amountCents), containsAll([1500, 500]));
  });
}
