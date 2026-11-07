import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class VoidMovement {
  const VoidMovement(this._repository);

  final MovementRepository _repository;

  Future<void> call({
    required String vendorUid,
    required String movementId,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(movementId);
    if (uid == null || id == null) {
      throw const LedgerException('Sesión inválida. Vuelve a entrar.');
    }
    return _repository.voidById(vendorUid: uid, id: id);
  }
}
