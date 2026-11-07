import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:geolocator/geolocator.dart';

/// GPS nativo. Sin APIs nuestras. Solo "mientras usas la app".
class GeolocatorLocationGateway implements LocationGateway {
  @override
  Future<String?> ensureReady() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return 'Activa la ubicación del teléfono.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Sin permiso de ubicación no puedo usar el GPS.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'El permiso de ubicación está bloqueado. Ábrelo en Ajustes.';
    }
    return null;
  }

  @override
  Future<GeoFix?> readFix() async {
    final last = await Geolocator.getLastKnownPosition();
    final known = _asFix(last);
    if (known != null) return known;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    ).timeout(const Duration(seconds: 18));
    return _asFix(position);
  }

  GeoFix? _asFix(Position? position) {
    if (position == null) return null;
    final lat = InputSanitizer.latitude(position.latitude);
    final lng = InputSanitizer.longitude(position.longitude);
    if (lat == null || lng == null) return null;
    return GeoFix(latitude: lat, longitude: lng);
  }
}
