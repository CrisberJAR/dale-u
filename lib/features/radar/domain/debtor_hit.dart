import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/ledger/domain/ledger_spoken.dart';

/// Un deudor al que el vendedor acaba de acercarse.
final class DebtorHit {
  const DebtorHit({
    required this.clientId,
    required this.name,
    required this.balanceCents,
    required this.meters,
  });

  final String clientId;
  final String name;
  final int balanceCents;
  final double meters;

  String get screenLine => '$name debe S/ ${formatSoles(balanceCents)}.';

  String get spokenLine => 'Cerca de $name. ${debtSpokenReply(
        clientName: name,
        balance: balanceCents,
      )}';
}
