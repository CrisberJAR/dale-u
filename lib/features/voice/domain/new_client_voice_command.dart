/// Interpreta frases de alta de cliente. Todo ocurre en el teléfono.
final class NewClientVoiceCommand {
  const NewClientVoiceCommand({required this.name, required this.phone});

  final String name;
  final String phone;

  bool get hasName => name.trim().length >= 2;

  /// `null` si la frase no es un alta de cliente.
  /// `name` vacío si dijo el comando pero no el nombre.
  static NewClientVoiceCommand? tryParse(String spoken) {
    final cleaned = spoken.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return null;

    final match = _trigger.firstMatch(cleaned);
    if (match == null) return null;

    var rest = cleaned.substring(match.end).trim();
    rest = rest.replaceFirst(RegExp(r'^[\s:,.\-]+'), '').trim();
    if (rest.isEmpty) {
      return const NewClientVoiceCommand(name: '', phone: '');
    }

    var namePart = rest;
    var phonePart = '';

    final marker = _phoneMarker.firstMatch(rest);
    if (marker != null) {
      namePart = rest.substring(0, marker.start).trim();
      phonePart = rest.substring(marker.end).trim();
    } else {
      final trailing = _trailingDigits.firstMatch(rest);
      if (trailing != null) {
        namePart = trailing.group(1)!.trim();
        phonePart = trailing.group(2)!;
      }
    }

    if (namePart.isNotEmpty) {
      namePart = namePart.replaceFirst(RegExp(r'\s+con$', caseSensitive: false), '').trim();
    }

    return NewClientVoiceCommand(
      name: _prettyName(namePart),
      phone: phonePart,
    );
  }

  static final _trigger = RegExp(
    r'^(?:por favor |oye |okey |ok |bueno )?'
    r'(?:quiero |voy a |vamos a )?'
    r'(?:'
    r'(?:anotar |anota |agregar |agrega |añadir |anadir |añade |anade |registrar |registra )'
    r'(?:un |una )?(?:nuevo |nueva )?client[ae]s?\b'
    r'|'
    r'(?:un |una )?(?:nuevo |nueva )client[ae]s?\b'
    r')'
    r'(?:\s+(?:llamado|llamada|de nombre|que se llama|se llama)\b)?',
    caseSensitive: false,
  );

  static final _phoneMarker = RegExp(
    r'\b(?:tel[eé]fono|celular|n[uú]meros?|cel|whatsapp|whatsap)\b',
    caseSensitive: false,
  );

  static final _trailingDigits = RegExp(
    r'^(.+?)\s+((?:\+?\d[\d\s\-()]{6,}))$',
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
