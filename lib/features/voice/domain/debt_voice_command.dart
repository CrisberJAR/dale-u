/// Interpreta consulta de deuda por voz. Todo local, sin red.
final class DebtVoiceCommand {
  const DebtVoiceCommand({required this.name});

  final String name;

  bool get hasName => name.trim().length >= 2;

  static const missingNameHint =
      'Dime el nombre. Por ejemplo: cuánto debe María.';

  /// `null` si la frase no es una consulta de saldo.
  static DebtVoiceCommand? tryParse(String spoken) {
    final cleaned = spoken.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;

    final match = _trigger.firstMatch(cleaned);
    if (match == null) return null;

    var rest = cleaned.substring(match.end).trim();
    rest = rest.replaceFirst(RegExp(r'^[\s:,.\-]+'), '').trim();
    rest = rest.replaceFirst(RegExp(r'^(?:de |a )', caseSensitive: false), '');
    return DebtVoiceCommand(name: _prettyName(rest));
  }

  static final _trigger = RegExp(
    r'^(?:por favor |oye |okey |ok |bueno )?'
    r'(?:'
    // El \b evita comerse el nombre: "cuánto debe Delia" no es "debe de Lia".
    r'(?:cu[aá]nto |qu[eé] )(?:me )?(?:le )?(?:nos )?deben?\b(?:\s+de\b)?'
    r'|'
    r'(?:cu[aá]l es )?(?:el |la )?(?:saldos?|deudas?)\b(?:\s+de\b)?'
    r'|'
    r'(?:consulta |consultar )(?:el |la )?(?:saldos?|deudas?)\b(?:\s+de\b)?'
    r')',
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
