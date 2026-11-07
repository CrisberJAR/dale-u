import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/time/peru_time.dart';

/// Fecha/hora usable para anotar o corregir un movimiento.
DateTime requireOccurredAt(DateTime raw) {
  final stamp = raw.toUtc();
  final latest = DateTime.now().toUtc().add(const Duration(days: 1));
  if (stamp.isAfter(latest)) {
    throw const LedgerException('La fecha y hora no pueden ser futuras.');
  }
  if (toPeru(stamp).year < 2020) {
    throw const LedgerException('Revisa la fecha del movimiento.');
  }
  return stamp;
}
