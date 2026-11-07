import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/occurred_at.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class RecordMovement {
  const RecordMovement(this._repository, {this.now});

  final MovementRepository _repository;
  final DateTime Function()? now;

  Future<Movement> call({
    required String vendorUid,
    required String clientId,
    required MovementKind kind,
    required int amountCents,
    DateTime? occurredAt,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const LedgerException('Sesión inválida. Vuelve a entrar.');
    }
    final amount = InputSanitizer.centimos(amountCents);
    if (amount == null) {
      throw const LedgerException(
        'Dime un monto válido. Por ejemplo: fiado a María 5 soles.',
      );
    }
    final stamp = occurredAt == null
        ? (now?.call() ?? DateTime.now())
        : requireOccurredAt(occurredAt);
    return _repository.record(
      Movement(
        id: 'pending',
        vendorUid: uid,
        clientId: id,
        kind: kind,
        amountCents: amount,
        occurredAt: stamp,
        createdAt: stamp,
      ),
    );
  }
}
