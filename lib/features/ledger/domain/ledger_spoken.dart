import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';

String ledgerSpokenConfirmation({
  required MovementKind kind,
  required String clientName,
  required int amountCents,
  required int newBalance,
  required DateTime at,
}) {
  final amount = spokenSoles(amountCents);
  final stamp = spokenStamp(at);
  final balanceBit = newBalance > 0
      ? ' Debe ${spokenSoles(newBalance)}.'
      : (newBalance < 0
            ? ' Le queda a favor ${spokenSoles(-newBalance)}.'
            : ' Quedó en cero.');
  return 'Listo. ${kind.spokenLabel} de $amount a $clientName. '
      'Anotado el $stamp.$balanceBit';
}

String debtSpokenReply({
  required String clientName,
  required int balance,
}) {
  if (balance > 0) {
    return '$clientName debe ${spokenSoles(balance)}.';
  }
  if (balance < 0) {
    return '$clientName tiene ${spokenSoles(-balance)} a favor.';
  }
  return '$clientName no debe nada.';
}
