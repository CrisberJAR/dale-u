import 'package:dale_u/core/security/input_sanitizer.dart';

/// Nombre del vendedor ya limpio. Vacío si no vino: la pantalla decide qué
/// mostrar en su lugar.
String vendorNameOrEmpty(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return '';
  return InputSanitizer.displayName(trimmed);
}

/// Marcador del comprador: "este vendedor me tiene anotado con esta ficha".
/// No da permisos; leer la deuda depende de `linkedUid` en la ficha.
final class LinkedAccount {
  const LinkedAccount({
    required this.vendorUid,
    required this.clientId,
    this.vendorName = '',
  });

  final String vendorUid;
  final String clientId;
  final String vendorName;

  /// Clave estable: un mismo vendedor y ficha no se duplican.
  String get id => '${vendorUid}_$clientId';

  bool sameAs(LinkedAccount other) {
    return vendorUid == other.vendorUid && clientId == other.clientId;
  }

  LinkedAccount copyWith({String? vendorName}) {
    return LinkedAccount(
      vendorUid: vendorUid,
      clientId: clientId,
      vendorName: vendorName ?? this.vendorName,
    );
  }
}
