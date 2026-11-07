import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class ListClientMovements {
  const ListClientMovements(this._repository);

  final MovementRepository _repository;

  Future<List<Movement>> call({
    required String vendorUid,
    required String clientId,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) return const [];
    return _repository.listByClient(vendorUid: uid, clientId: id);
  }
}
