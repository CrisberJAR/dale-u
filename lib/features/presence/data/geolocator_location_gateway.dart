import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:dale_u/features/presence/domain/presence_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// GPS nativo. Sin APIs nuestras. Permiso "mientras usas la app": en
/// Android el servicio en primer plano cuenta como uso, así que no hace
/// falta el permiso de ubicación "todo el tiempo".
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

    // Android 13+: sin este permiso la notificación de "En ruta" no se ve.
    // El GPS sigue igual, así que no bloquea.
    if (_isAndroid) {
      try {
        await Permission.notification.request();
      } catch (error) {
        debugPrint('Notification permission failed: ${error.runtimeType}');
      }
    }
    return null;
  }

  @override
  Future<GeoFix?> readFix() async {
    // El último punto conocido puede tener horas: solo vale si es reciente.
    final last = await Geolocator.getLastKnownPosition();
    final known = _asFreshFix(last);
    if (known != null) return known;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    ).timeout(const Duration(seconds: 18));
    return _asFix(position, checkAccuracy: false);
  }

  @override
  Stream<GeoFix> watch() {
    return Geolocator.getPositionStream(locationSettings: _streamSettings())
        .map((position) => _asFix(position))
        .where((fix) => fix != null)
        .cast<GeoFix>();
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static LocationSettings _streamSettings() {
    if (_isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Dale U: estás en ruta',
          notificationText:
              'Tus clientes ven por dónde vas. Sal de la ruta para apagarlo.',
          notificationChannelName: 'Ruta en curso',
          setOngoing: true,
          enableWakeLock: true,
        ),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  GeoFix? _asFreshFix(Position? position) {
    if (position == null) return null;
    final age = DateTime.now().difference(position.timestamp);
    if (age.isNegative || age > PresencePolicy.maxFixAge) return null;
    return _asFix(position);
  }

  GeoFix? _asFix(Position? position, {bool checkAccuracy = true}) {
    if (position == null) return null;
    if (checkAccuracy &&
        position.accuracy > PresencePolicy.maxAccuracyMeters) {
      return null;
    }
    final lat = InputSanitizer.latitude(position.latitude);
    final lng = InputSanitizer.longitude(position.longitude);
    if (lat == null || lng == null) return null;
    return GeoFix(latitude: lat, longitude: lng);
  }
}
