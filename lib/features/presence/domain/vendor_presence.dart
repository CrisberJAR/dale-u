import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/presence_policy.dart';

/// Último punto publicado. Un solo documento en la nube, no un historial.
final class VendorPresence {
  const VendorPresence({
    required this.onRoute,
    required this.updatedAt,
    this.fix,
  });

  final bool onRoute;
  final DateTime updatedAt;
  final GeoFix? fix;

  bool get hasFix => fix != null;

  bool isVisibleAt(DateTime now) {
    return onRoute && hasFix && PresencePolicy.isFresh(updatedAt, now);
  }

  static VendorPresence? tryParse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final millis = _asInt(data['updatedAt']);
    if (millis == null) return null;
    final updatedAt = fromEpochMillis(millis);
    final onRoute = data['onRoute'] == true;
    GeoFix? fix;
    if (onRoute) {
      final lat = InputSanitizer.latitude(_asDouble(data['latitude']));
      final lng = InputSanitizer.longitude(_asDouble(data['longitude']));
      if (lat != null && lng != null) {
        fix = GeoFix(latitude: lat, longitude: lng);
      }
    }
    return VendorPresence(onRoute: onRoute, updatedAt: updatedAt, fix: fix);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }
}
