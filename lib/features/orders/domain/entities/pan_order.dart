import 'package:dale_u/core/format/money.dart';

/// Recordatorio local de pan para un día. No es un cliente de la ruta.
final class PanOrder {
  const PanOrder({
    required this.id,
    required this.vendorUid,
    required this.label,
    required this.deliveryDateKey,
    required this.createdAt,
  });

  final String id;
  final String vendorUid;

  /// Texto libre: quién pidió o qué dejar. Puede no estar en la libreta.
  final String label;

  /// Día de entrega en Perú, YYYYMMDD.
  final int deliveryDateKey;
  final DateTime createdAt;

  String get spokenDay => spokenDateKey(deliveryDateKey);

  String get dateLabel => peruDateKeyLabel(deliveryDateKey);
}
