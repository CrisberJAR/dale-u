/// Limpia textos que llegan de Google o del usuario antes de mostrarlos.
/// Evita caracteres de control y recorta longitudes (defensa ante crashes).
final class InputSanitizer {
  const InputSanitizer._();

  static final _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  static const maxNameLength = 80;
  static const maxEmailLength = 254;
  static const maxUidLength = 128;
  static const maxPhoneLength = 20;
  static final _uidPattern = RegExp(r'^[a-zA-Z0-9_-]+$');

  static String displayName(String? raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty) return 'Usuario';
    return _limit(cleaned, maxNameLength);
  }

  static String email(String? raw) {
    final cleaned = _clean(raw).toLowerCase();
    if (cleaned.isEmpty) return '';
    return _limit(cleaned, maxEmailLength);
  }

  /// UID de Firebase: solo caracteres seguros para usarlo como clave local.
  static String? uid(String? raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty || cleaned.length > maxUidLength) return null;
    if (!_uidPattern.hasMatch(cleaned)) return null;
    return cleaned;
  }

  /// Nombre de cliente: obligatorio, mínimo 2 caracteres. Null si no sirve.
  static String? personName(String? raw) {
    final cleaned = _clean(raw).replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length < 2) return null;
    return _limit(cleaned, maxNameLength);
  }

  /// Teléfono: solo dígitos y símbolos típicos. Vacío si no hay nada usable.
  static String phone(String? raw) {
    final cleaned = _clean(raw).replaceAll(RegExp(r'[^0-9+\-() ]'), '');
    final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty || compact.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
      return '';
    }
    return _limit(compact, maxPhoneLength);
  }

  static const maxCentimos = 1000000000;
  static const minCentimos = 1;

  /// Monto en céntimos. Null si no es un valor usable.
  static int? centimos(int? raw) {
    if (raw == null) return null;
    if (raw < minCentimos || raw > maxCentimos) return null;
    return raw;
  }

  static const maxSpokenLength = 280;
  static const maxNoticeLength = 200;

  /// Aviso del vendedor a clientes con app. Null si no hay texto usable.
  static String? notice(String? raw) {
    final cleaned = spokenText(raw);
    if (cleaned.length < 2) return null;
    return _limit(cleaned, maxNoticeLength);
  }

  /// Texto dictado: sin controles, recortado. No ejecuta comandos.
  static String spokenText(String? raw) {
    final cleaned = _clean(raw).replaceAll(RegExp(r'\s+'), ' ');
    return _limit(cleaned, maxSpokenLength);
  }

  /// Coordenada usable. Null si está fuera del planeta o no es número.
  static double? latitude(double? raw) {
    if (raw == null || raw.isNaN || raw.isInfinite) return null;
    if (raw < -90 || raw > 90) return null;
    return raw;
  }

  static double? longitude(double? raw) {
    if (raw == null || raw.isNaN || raw.isInfinite) return null;
    if (raw < -180 || raw > 180) return null;
    return raw;
  }

  static String? photoUrl(String? raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty) return null;
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'https')) {
      return null;
    }
    return cleaned;
  }

  static String _clean(String? raw) {
    return (raw ?? '').replaceAll(_controlChars, '').trim();
  }

  static String _limit(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }
}
