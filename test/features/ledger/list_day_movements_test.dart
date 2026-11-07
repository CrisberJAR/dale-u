import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_day_movements.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryMovements implements MovementRepository {
  final items = <Movement>[];

  @override
  Future<Movement> record(Movement movement) async => movement;

  @override
  Future<Map<String, int>> balancesByVendor(String vendorUid) async => {};

  @override
  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  }) async => const [];

  @override
  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) async => items.first;

  @override
  Future<void> voidById({
    required String vendorUid,
    required String id,
  }) async {}

  @override
  Future<void> syncPending(String vendorUid) async {}

  @override
  Future<List<Movement>> listByDay({
    required String vendorUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final from = start.toUtc();
    final to = end.toUtc();
    return items.where((item) {
      if (item.vendorUid != vendorUid || item.voided) return false;
      final at = item.occurredAt.toUtc();
      return !at.isBefore(from) && at.isBefore(to);
    }).toList();
  }
}

Movement _item({
  required String id,
  required MovementKind kind,
  required int cents,
  required DateTime at,
  String vendor = 'uid123',
  bool voided = false,
}) {
  return Movement(
    id: id,
    vendorUid: vendor,
    clientId: 'c1',
    kind: kind,
    amountCents: cents,
    occurredAt: at,
    createdAt: at,
    pendingSync: false,
    voided: voided,
  );
}

void main() {
  test('suma fiados y pagos del día en hora de Perú, sin anulados', () async {
    final repo = _MemoryMovements();
    repo.items.addAll([
      _item(
        id: 'a',
        kind: MovementKind.fiado,
        cents: 5000,
        at: fromPeruWallClock(DateTime(2026, 9, 2, 8)),
      ),
      _item(
        id: 'b',
        kind: MovementKind.pago,
        cents: 2000,
        at: fromPeruWallClock(DateTime(2026, 9, 2, 18)),
      ),
      _item(
        id: 'c',
        kind: MovementKind.fiado,
        cents: 800,
        at: fromPeruWallClock(DateTime(2026, 9, 2, 12)),
        voided: true,
      ),
      _item(
        id: 'd',
        kind: MovementKind.pago,
        cents: 999,
        at: fromPeruWallClock(DateTime(2026, 9, 1, 23, 50)),
      ),
      _item(
        id: 'e',
        kind: MovementKind.fiado,
        cents: 100,
        at: fromPeruWallClock(DateTime(2026, 9, 2, 9)),
        vendor: 'otro',
      ),
    ]);

    final close = await ListDayMovements(repo)(
      vendorUid: 'uid123',
      dateKey: 20260902,
    );

    expect(close.fiadoCount, 1);
    expect(close.fiadoCents, 5000);
    expect(close.pagoCount, 1);
    expect(close.pagoCents, 2000);
    expect(close.movements, hasLength(2));
  });
}
