import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';

/// Totales de un día civil (hora de Perú). Sin anulados.
final class DailyClose {
  const DailyClose({
    required this.dateKey,
    required this.movements,
  });

  final int dateKey;
  final List<Movement> movements;

  static DailyClose fromMovements({
    required int dateKey,
    required List<Movement> movements,
  }) {
    return DailyClose(dateKey: dateKey, movements: List.unmodifiable(movements));
  }

  int get fiadoCents {
    var total = 0;
    for (final item in movements) {
      if (item.kind == MovementKind.fiado) total += item.amountCents;
    }
    return total;
  }

  int get pagoCents {
    var total = 0;
    for (final item in movements) {
      if (item.kind == MovementKind.pago) total += item.amountCents;
    }
    return total;
  }

  int get fiadoCount =>
      movements.where((item) => item.kind == MovementKind.fiado).length;

  int get pagoCount =>
      movements.where((item) => item.kind == MovementKind.pago).length;

  bool get isEmpty => movements.isEmpty;
}
