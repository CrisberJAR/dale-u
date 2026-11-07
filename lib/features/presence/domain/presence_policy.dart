import 'package:dale_u/features/presence/domain/geo_fix.dart';

/// Cuándo vale la pena escribir en Firestore. Evita saturar y gastar batería.
///
/// El aviso "tu panadero está cerca" (200 m y 40 m) necesita puntos
/// seguidos mientras el vendedor camina: se sube si avanzó [minMoveMeters]
/// y pasaron al menos [minGap]. Si está quieto, un latido cada
/// [heartbeat] lo mantiene visible en el mapa.
final class PresencePolicy {
  const PresencePolicy();

  static const minGap = Duration(seconds: 10);
  static const minMoveMeters = 15.0;
  static const heartbeat = Duration(minutes: 4);
  static const freshWindow = Duration(minutes: 15);

  /// Una lectura más vieja o menos precisa que esto no se publica.
  static const maxFixAge = Duration(minutes: 2);
  static const maxAccuracyMeters = 100.0;

  /// Si el punto tiene más de 15 minutos, no se pinta como si estuviera ahí.
  static bool isFresh(DateTime updatedAt, DateTime now) {
    return !now.difference(updatedAt).isNegative &&
        now.difference(updatedAt) <= freshWindow;
  }

  /// El primer punto siempre se sube. Luego: avanzar 15 m (con 10 s de
  /// separación) o, aunque esté quieto, un latido cada 4 minutos.
  static bool shouldPublish({
    required GeoFix? lastFix,
    required DateTime? lastAt,
    required GeoFix next,
    required DateTime now,
  }) {
    if (lastFix == null || lastAt == null) return true;
    final elapsed = now.difference(lastAt);
    if (elapsed.isNegative) return true;
    if (elapsed >= heartbeat) return true;
    if (elapsed < minGap) return false;
    return lastFix.metersTo(next) >= minMoveMeters;
  }
}
