import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';

/// Lo que se muestra en el estado de cuenta: el saldo de hoy y los
/// movimientos vigentes. Lo anulado no aparece.
final class Statement {
  Statement({
    required this.vendorName,
    required this.clientName,
    required List<Movement> movements,
    required this.generatedAt,
    int? balanceCents,
  }) : movements = List.unmodifiable(
         movements.where((movement) => !movement.voided).toList()
           ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt)),
       ),
       balanceCents = balanceCents ?? _sum(movements);

  final String vendorName;
  final String clientName;
  final List<Movement> movements;
  final DateTime generatedAt;

  /// Positivo: debe. Negativo: tiene a favor.
  final int balanceCents;

  String get vendorLabel => vendorName.trim().isEmpty ? 'Tu panadero' : vendorName;

  String get balanceLine {
    if (balanceCents > 0) return 'Debe S/ ${formatSoles(balanceCents)}';
    if (balanceCents < 0) return 'A favor S/ ${formatSoles(-balanceCents)}';
    return 'Está al día';
  }

  static int _sum(List<Movement> movements) {
    var total = 0;
    for (final movement in movements) {
      total += movement.signedCents;
    }
    return total;
  }
}
