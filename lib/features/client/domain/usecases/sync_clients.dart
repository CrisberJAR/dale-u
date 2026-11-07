import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class SyncClients {
  const SyncClients(this._repository);

  final ClientRepository _repository;

  Future<void> call(String vendorUid) => _repository.syncPending(vendorUid);
}
