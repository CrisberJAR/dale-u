import 'package:dale_u/features/presence/domain/geo_fix.dart';

/// GPS del teléfono. El permiso se pide al usarlo, no al abrir la app.
abstract class LocationGateway {
  /// `null` si ya se puede leer. Si no, el mensaje para la pantalla.
  Future<String?> ensureReady();

  /// Una lectura fresca. `null` si el GPS no respondió a tiempo.
  Future<GeoFix?> readFix();

  /// Lecturas continuas mientras dure la ruta. En Android corre con un
  /// servicio en primer plano, así sigue con la pantalla apagada.
  Stream<GeoFix> watch();
}
