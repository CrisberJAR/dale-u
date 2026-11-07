import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';
import 'package:dale_u/features/ledger/domain/usecases/record_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/update_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/void_movement.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryMovements implements MovementRepository {
  final items = <Movement>[];

  @override
  Future<Movement> record(Movement movement) async {
    final saved = Movement(
      id: 'm${items.length}',
      vendorUid: movement.vendorUid,
      clientId: movement.clientId,
      kind: movement.kind,
      amountCents: movement.amountCents,
      occurredAt: movement.occurredAt,
      createdAt: movement.createdAt,
    );
    items.add(saved);
    return saved;
  }

  @override
  Future<Map<String, int>> balancesByVendor(String vendorUid) async {
    final balances = <String, int>{};
    for (final item in items.where((m) => m.vendorUid == vendorUid)) {
      balances[item.clientId] = (balances[item.clientId] ?? 0) + item.signedCents;
    }
    return balances;
  }

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

  @override
  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    return items
        .where((item) => item.vendorUid == vendorUid && item.clientId == clientId)
        .toList();
  }

  @override
  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(
      kind: kind,
      amountCents: amountCents,
      occurredAt: occurredAt,
    );
    return items[index];
  }

  @override
  Future<void> voidById({
    required String vendorUid,
    required String id,
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(voided: true);
  }

  @override
  Future<void> syncPending(String vendorUid) async {}
}

void main() {
  test('guarda fiado local con sello de fecha', () async {
    final repo = _MemoryMovements();
    final stamp = DateTime(2026, 8, 29, 19, 49);
    final useCase = RecordMovement(repo, now: () => stamp);

    final movement = await useCase(
      vendorUid: 'uid123',
      clientId: 'client-1',
      kind: MovementKind.fiado,
      amountCents: 5000,
    );

    expect(movement.kind, MovementKind.fiado);
    expect(movement.amountCents, 5000);
    expect(movement.occurredAt, stamp);
    expect(movement.pendingSync, isTrue);
    expect(await repo.balancesByVendor('uid123'), {'client-1': 5000});
  });

  test('un pago resta del saldo', () async {
    final repo = _MemoryMovements();
    final useCase = RecordMovement(repo, now: () => DateTime(2026));
    await useCase(
      vendorUid: 'uid123',
      clientId: 'c1',
      kind: MovementKind.fiado,
      amountCents: 5000,
    );
    await useCase(
      vendorUid: 'uid123',
      clientId: 'c1',
      kind: MovementKind.pago,
      amountCents: 2000,
    );
    expect(await repo.balancesByVendor('uid123'), {'c1': 3000});
  });

  test('anular un fiado lo saca del saldo', () async {
    final repo = _MemoryMovements();
    final useCase = RecordMovement(repo, now: () => DateTime(2026));
    final movement = await useCase(
      vendorUid: 'uid123',
      clientId: 'c1',
      kind: MovementKind.fiado,
      amountCents: 5000,
    );
    await VoidMovement(repo)(vendorUid: 'uid123', movementId: movement.id);
    expect(await repo.balancesByVendor('uid123'), {'c1': 0});
  });

  test('permite corregir la fecha y hora del movimiento', () async {
    final repo = _MemoryMovements();
    final recorded = await RecordMovement(repo, now: () => DateTime.utc(2026, 8, 29, 20))(
      vendorUid: 'uid123',
      clientId: 'c1',
      kind: MovementKind.fiado,
      amountCents: 5000,
    );
    final corrected = DateTime.utc(2026, 8, 29, 15, 30);
    final updated = await UpdateMovement(repo)(
      vendorUid: 'uid123',
      movementId: recorded.id,
      kind: MovementKind.fiado,
      amountCents: 5000,
      occurredAt: corrected,
    );
    expect(updated.occurredAt.toUtc(), corrected);
  });

  test('permite anotar un fiado con fecha elegida a mano', () async {
    final repo = _MemoryMovements();
    final stamp = DateTime.utc(2026, 9, 2, 15, 30);
    final movement = await RecordMovement(repo)(
      vendorUid: 'uid123',
      clientId: 'c1',
      kind: MovementKind.fiado,
      amountCents: 150,
      occurredAt: stamp,
    );
    expect(movement.occurredAt.toUtc(), stamp);
    expect(movement.amountCents, 150);
  });
}
