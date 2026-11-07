import 'dart:math';

/// Un punto GPS. Sin red: solo números.
final class GeoFix {
  const GeoFix({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// Distancia en metros (fórmula de haversine).
  double metersTo(GeoFix other) {
    const earth = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLng = _rad(other.longitude - longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(latitude)) *
            cos(_rad(other.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * earth * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double degrees) => degrees * pi / 180;
}
