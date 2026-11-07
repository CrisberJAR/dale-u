import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/occurred_at.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class UpdateMovement {
  const UpdateMovement(this._repository);

  final MovementRepository _repository;

  Future<Movement> call({
    required String vendorUid,
    required String movementId,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(movementId);
    if (uid == null || id == null) {
      throw const LedgerException('Sesión inválida. Vuelve a entrar.');
    }
    final amount = InputSanitizer.centimos(amountCents);
    if (amount == null) {
      throw const LedgerException(
        'Escribe un monto válido en soles, por ejemplo 1.50.',
      );
    }
    final stamp = requireOccurredAt(occurredAt);
    return _repository.updateDetails(
      vendorUid: uid,
      id: id,
      kind: kind,
      amountCents: amount,
      occurredAt: stamp,
    );
  }
}
