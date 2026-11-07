/// Cliente desactivado, al día y un mes sin movimientos: se borra del todo.
///
/// Si todavía debe (o tiene saldo a favor) **nunca** se borra: borrar la
/// ficha borraría la deuda en la nube y en el teléfono, sin vuelta atrás.
final class InactiveClientPolicy {
  const InactiveClientPolicy._();

  static const inactivity = Duration(days: 30);

  static bool shouldPurge({
    required bool active,
    required DateTime updatedAt,
    required DateTime? lastMovementAt,
    required DateTime now,
    int balanceCents = 0,
  }) {
    if (active) return false;
    if (balanceCents != 0) return false;
    var last = updatedAt;
    if (lastMovementAt != null && lastMovementAt.isAfter(last)) {
      last = lastMovementAt;
    }
    final elapsed = now.difference(last);
    if (elapsed.isNegative) return false;
    return elapsed >= inactivity;
  }
}
