import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class SyncMovements {
  const SyncMovements(this._repository);

  final MovementRepository _repository;

  Future<void> call(String vendorUid) {
    return _repository.syncPending(vendorUid);
  }
}
