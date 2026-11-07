/// "Deshacer", "borra el último", "anula el último", "me equivoqué".
///
/// Anula el último fiado o pago dicho por voz, por si el teléfono entendió
/// mal el monto o el nombre.
final class UndoVoiceCommand {
  const UndoVoiceCommand._();

  static final _pattern = RegExp(
    r'^(?:deshac(?:er|e|elo)|deshaz(?:lo)?|me equivoqu[eé]'
    r'|(?:borr|anul|cancel|quit)(?:a|ar|alo)\s+(?:el\s+|lo\s+)?[uú]ltimo'
    r'(?:\s+(?:fiado|pago|movimiento))?)$',
    caseSensitive: false,
  );

  static bool matches(String spoken) {
    final cleaned = spoken
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!¡?¿]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return _pattern.hasMatch(cleaned);
  }
}
