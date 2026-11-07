/// Interpreta "buscar María" (y similares). Todo local, sin red.
final class SearchVoiceCommand {
  const SearchVoiceCommand({required this.query});

  final String query;

  bool get hasQuery => query.trim().length >= 2;

  static const missingQueryHint =
      'Dime el nombre. Por ejemplo: buscar María.';

  /// `null` si la frase no es un comando explícito de búsqueda.
  static SearchVoiceCommand? tryParse(String spoken) {
    final cleaned = spoken.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;

    final match = _trigger.firstMatch(cleaned);
    if (match == null) return null;

    var rest = cleaned.substring(match.end).trim();
    rest = rest.replaceFirst(RegExp(r'^[\s:,.\-]+'), '').trim();
    rest = rest.replaceFirst(RegExp(r'^(?:a |al |de |el |la )', caseSensitive: false), '');
    rest = rest.replaceFirst(
      RegExp(r'^client[ae]\s+', caseSensitive: false),
      '',
    );
    return SearchVoiceCommand(query: _prettyName(rest));
  }

  /// Nombre suelto para la barra (después de los otros comandos).
  /// Solo si de verdad parece un nombre: una frase entera con montos o
  /// palabras de fiado dejaría la lista vacía y parece que no se guardó nada.
  static String? asBareQuery(String spoken) {
    final cleaned = spoken.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length < 2) return null;
    if (RegExp(r'\d').hasMatch(cleaned)) return null;
    if (_notAName.hasMatch(cleaned)) return null;
    if (cleaned.split(' ').length > 3) return null;
    return _prettyName(cleaned);
  }

  static final _notAName = RegExp(
    r'\b(?:fiado|fiados|fiar|fia|fía|pago|pagos|pagar|pagu[eé]|pag[oó]|'
    r'cobro|cobrar|abono|abonos|sol|soles|c[eé]ntimos?|centavos?|'
    r'peso|pesos|mil|millones|'
    r'debe|deuda|saldo|client[ae]s?)\b',
    caseSensitive: false,
  );

  static final _trigger = RegExp(
    r'^(?:por favor |oye |okey |ok |bueno )?'
    r'(?:quiero |voy a |vamos a )?'
    r'(?:buscar|busca|búscame|buscame|encuentra|encuentre)\b'
    // El \b evita comerse el nombre: "buscar Melissa" no es "buscar me Lissa".
    r'(?:\s+me\b)?'
    r'(?:\s+(?:a|al|de)\b)?',
    caseSensitive: false,
  );

  static String _prettyName(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}
