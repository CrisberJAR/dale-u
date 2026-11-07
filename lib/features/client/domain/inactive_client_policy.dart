/// Cliente desactivado y un mes sin movimientos: se borra del todo.
final class InactiveClientPolicy {
  const InactiveClientPolicy._();

  static const inactivity = Duration(days: 30);

  static bool shouldPurge({
    required bool active,
    required DateTime updatedAt,
    required DateTime? lastMovementAt,
    required DateTime now,
  }) {
    if (active) return false;
    var last = updatedAt;
    if (lastMovementAt != null && lastMovementAt.isAfter(last)) {
      last = lastMovementAt;
    }
    final elapsed = now.difference(last);
    if (elapsed.isNegative) return false;
    return elapsed >= inactivity;
  }
}
