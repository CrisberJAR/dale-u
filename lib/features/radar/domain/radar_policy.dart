/// Radio local. No hay geocerca en la nube.
final class RadarPolicy {
  const RadarPolicy();

  /// Entras: avisa. Un poco más lejos: ya saliste, puede volver a avisar.
  static const approachMeters = 150.0;
  static const leaveMeters = 220.0;
}
