import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_remote_datasource.dart';
import 'package:dale_u/features/ledger/data/sync/movement_synchronizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryLocal implements MovementPendingStore {
  final pending = <Movement>[];
  final all = <String, Movement>{};

  @override
  Future<List<Movement>> listPending(String vendorUid) async =>
      pending.where((item) => item.vendorUid == vendorUid).toList();

  @override
  Future<void> markSynced(String id) async {
    pending.removeWhere((item) => item.id == id);
    final current = all[id];
    if (current != null) {
      all[id] = current.copyWith(pendingSync: false);
    }
  }

  @override
  Future<void> insertIfAbsent(Movement movement) async {
    all.putIfAbsent(movement.id, () => movement);
  }
}

class _MemoryRemote implements MovementRemoteDataSource {
  final uploaded = <Movement>[];
  List<Movement> remote = [];

  @override
  Future<void> upsert(Movement movement) async {
    uploaded.add(movement);
  }

  @override
  Future<List<Movement>> fetchByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    return remote
        .where(
          (item) => item.vendorUid == vendorUid && item.clientId == clientId,
        )
        .toList();
  }
}

void main() {
  final sample = Movement(
    id: 'mov-001-aaaa',
    vendorUid: 'uid123',
    clientId: 'client-1',
    kind: MovementKind.fiado,
    amountCents: 5000,
    occurredAt: DateTime(2026, 8, 29),
    createdAt: DateTime(2026, 8, 29),
  );

  test('sube fiados pendientes y los marca sincronizados', () async {
    final local = _MemoryLocal()
      ..pending.add(sample)
      ..all[sample.id] = sample;
    final remote = _MemoryRemote();
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1'],
    );

    await sync.sync('uid123');

    expect(remote.uploaded, hasLength(1));
    expect(remote.uploaded.first.amountCents, 5000);
    expect(local.pending, isEmpty);
    expect(local.all[sample.id]!.pendingSync, isFalse);
  });

  test('trae movimientos remotos que no existen en local', () async {
    final local = _MemoryLocal();
    final remote = _MemoryRemote()..remote = [sample];
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1'],
    );

    await sync.sync('uid123');

    expect(local.all[sample.id], isNotNull);
    expect(local.all[sample.id]!.kind, MovementKind.fiado);
  });
}
