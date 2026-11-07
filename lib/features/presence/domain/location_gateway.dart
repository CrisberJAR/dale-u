import 'package:dale_u/features/presence/domain/geo_fix.dart';

/// GPS del teléfono. El permiso se pide al usarlo, no al abrir la app.
abstract class LocationGateway {
  /// `null` si ya se puede leer. Si no, el mensaje para la pantalla.
  Future<String?> ensureReady();

  Future<GeoFix?> readFix();
}
