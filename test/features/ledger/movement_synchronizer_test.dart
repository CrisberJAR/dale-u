import 'package:dale_u/core/sync/sync_cursor_store.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_remote_datasource.dart';
import 'package:dale_u/features/ledger/data/sync/movement_synchronizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryLocal implements MovementPendingStore {
  final pending = <Movement>[];
  final all = <String, Movement>{};

  /// Simula que el vendedor edita mientras se sube.
  void Function()? duringPush;

  @override
  Future<List<Movement>> listPending(String vendorUid) async =>
      pending.where((item) => item.vendorUid == vendorUid).toList();

  @override
  Future<void> markSynced(Movement pushed) async {
    final current = all[pushed.id];
    if (current != null && current.amountCents != pushed.amountCents) {
      return; // Cambió mientras subía: sigue pendiente.
    }
    pending.removeWhere((item) => item.id == pushed.id);
    if (current != null) {
      all[pushed.id] = current.copyWith(pendingSync: false);
    }
  }

  @override
  Future<void> insertIfAbsent(Movement movement) async {
    all.putIfAbsent(movement.id, () => movement);
  }
}

class _MemoryRemote implements MovementRemoteDataSource {
  _MemoryRemote({this.local});

  final _MemoryLocal? local;
  final uploaded = <Movement>[];
  List<Movement> remote = [];
  bool failBatch = false;
  bool deltaReady = true;
  int fullPulls = 0;
  int deltaPulls = 0;

  @override
  Future<void> upsert(Movement movement) async {
    uploaded.add(movement);
  }

  @override
  Future<void> upsertAll(List<Movement> movements) async {
    if (failBatch) throw Exception('batch failed');
    local?.duringPush?.call();
    uploaded.addAll(movements);
  }

  @override
  Future<List<Movement>> fetchByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    fullPulls++;
    return remote
        .where(
          (item) => item.vendorUid == vendorUid && item.clientId == clientId,
        )
        .toList();
  }

  @override
  Future<MovementChanges> fetchChangedSince({
    required String vendorUid,
    required DateTime since,
  }) async {
    if (!deltaReady) throw const MovementDeltaUnavailable();
    deltaPulls++;
    return MovementChanges(movements: remote);
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

  test('si se edita mientras sube, queda pendiente para la próxima', () async {
    final local = _MemoryLocal()
      ..pending.add(sample)
      ..all[sample.id] = sample;
    local.duringPush = () {
      local.all[sample.id] = sample.copyWith(amountCents: 7000);
    };
    final remote = _MemoryRemote(local: local);
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1'],
    );

    await sync.sync('uid123');

    expect(local.pending, hasLength(1));
  });

  test('si el lote falla, reintenta uno por uno', () async {
    final local = _MemoryLocal()
      ..pending.add(sample)
      ..all[sample.id] = sample;
    final remote = _MemoryRemote()..failBatch = true;
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1'],
    );

    await sync.sync('uid123');

    expect(remote.uploaded, hasLength(1));
    expect(local.pending, isEmpty);
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

  test('con cursor: la primera vez baja todo, luego solo lo nuevo', () async {
    final local = _MemoryLocal();
    final remote = _MemoryRemote()..remote = [sample];
    var clock = DateTime.utc(2026, 9, 1, 8);
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1', 'client-2'],
      cursors: SyncCursorStore.memory(scope: 'movements'),
      now: () => clock,
    );

    await sync.sync('uid123');
    expect(remote.fullPulls, 2);
    expect(remote.deltaPulls, 0);

    clock = clock.add(const Duration(minutes: 10));
    await sync.sync('uid123');
    expect(remote.fullPulls, 2);
    expect(remote.deltaPulls, 1);
  });

  test('si falta el índice, cae a la bajada completa', () async {
    final local = _MemoryLocal();
    final remote = _MemoryRemote()..remote = [sample];
    var clock = DateTime.utc(2026, 9, 1, 8);
    final sync = MovementSynchronizer(
      local: local,
      remote: remote,
      listClientIds: (_) async => ['client-1'],
      cursors: SyncCursorStore.memory(scope: 'movements'),
      now: () => clock,
    );
    await sync.sync('uid123');
    remote.deltaReady = false;
    clock = clock.add(const Duration(minutes: 10));

    await sync.sync('uid123');

    expect(remote.fullPulls, 2);
    expect(local.all[sample.id], isNotNull);
  });
}
