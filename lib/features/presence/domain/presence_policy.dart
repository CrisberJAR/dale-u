import 'package:dale_u/features/presence/domain/geo_fix.dart';

/// Cuándo vale la pena escribir en Firestore. Evita saturar y gastar batería.
final class PresencePolicy {
  const PresencePolicy();

  static const interval = Duration(minutes: 5);
  static const minMoveMeters = 80.0;
  static const freshWindow = Duration(minutes: 15);

  /// GPS local para el radar. No sube a Firestore.
  static const localPoll = Duration(seconds: 30);

  /// Si el punto tiene más de 15 minutos, no se pinta como si estuviera ahí.
  static bool isFresh(DateTime updatedAt, DateTime now) {
    return !now.difference(updatedAt).isNegative &&
        now.difference(updatedAt) <= freshWindow;
  }

  /// El primer punto siempre se sube. Luego: 5 minutos **y** haberse movido.
  static bool shouldPublish({
    required GeoFix? lastFix,
    required DateTime? lastAt,
    required GeoFix next,
    required DateTime now,
  }) {
    if (lastFix == null || lastAt == null) return true;
    if (now.difference(lastAt) < interval) return false;
    return lastFix.metersTo(next) >= minMoveMeters;
  }
}
