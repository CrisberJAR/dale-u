import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:dale_u/features/client/data/sync/client_synchronizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryLocal implements ClientPendingStore {
  final pending = <Client>[];
  final all = <String, Client>{};

  @override
  Future<List<Client>> listPending(String vendorUid) async =>
      pending.where((c) => c.vendorUid == vendorUid).toList();

  @override
  Future<void> markSynced(Client pushed) async {
    pending.removeWhere((c) => c.id == pushed.id);
    final current = all[pushed.id];
    if (current != null) {
      all[pushed.id] = current.copyWith(pendingSync: false);
    }
  }

  @override
  Future<void> insertIfAbsent(Client client) async {
    all.putIfAbsent(client.id, () => client);
  }
}

class _MemoryRemote implements ClientRemoteDataSource {
  final uploaded = <Client>[];
  final publishedNames = <String>[];
  List<Client> remote = [];

  @override
  Future<void> upsert(Client client) async {
    uploaded.add(client);
  }

  @override
  Future<List<Client>> fetchByVendor(String vendorUid) async => remote;

  @override
  Future<void> publishVendorName(String vendorUid) async {
    publishedNames.add(vendorUid);
  }

  @override
  Future<void> deleteCascade({
    required String vendorUid,
    required String clientId,
    required String inviteCode,
  }) async {}
}

class _FailingRemote implements ClientRemoteDataSource {
  @override
  Future<void> upsert(Client client) async {
    throw Exception('permission-denied');
  }

  @override
  Future<List<Client>> fetchByVendor(String vendorUid) async => [];

  @override
  Future<void> publishVendorName(String vendorUid) async {
    throw Exception('permission-denied');
  }

  @override
  Future<void> deleteCascade({
    required String vendorUid,
    required String clientId,
    required String inviteCode,
  }) async {
    throw Exception('permission-denied');
  }
}

void main() {
  final sample = Client(
    id: 'client-001',
    vendorUid: 'uid123',
    name: 'Doña María',
    phone: '3001234567',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('sube pendientes y los marca sincronizados', () async {
    final local = _MemoryLocal()
      ..pending.add(sample)
      ..all[sample.id] = sample;
    final remote = _MemoryRemote();
    final sync = ClientSynchronizer(local: local, remote: remote);

    await sync.sync('uid123');

    expect(remote.uploaded, hasLength(1));
    expect(remote.uploaded.first.name, 'Doña María');
    expect(local.pending, isEmpty);
    expect(local.all[sample.id]!.pendingSync, isFalse);
  });

  test('trae clientes remotos que no existen en local', () async {
    final local = _MemoryLocal();
    final remote = _MemoryRemote()..remote = [sample];
    final sync = ClientSynchronizer(local: local, remote: remote);

    await sync.sync('uid123');

    expect(local.all[sample.id], isNotNull);
    expect(local.all[sample.id]!.name, 'Doña María');
  });

  test('si Firestore falla no marca el cliente como sincronizado', () async {
    final local = _MemoryLocal()
      ..pending.add(sample)
      ..all[sample.id] = sample;
    final remote = _FailingRemote();
    final sync = ClientSynchronizer(local: local, remote: remote);

    await expectLater(sync.sync('uid123'), throwsA(isA<Exception>()));
    expect(local.pending, isNotEmpty);
    expect(local.all[sample.id]!.pendingSync, isTrue);
  });
}
