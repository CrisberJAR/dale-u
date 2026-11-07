import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';

/// Interpreta montos dichos en español o en números. Devuelve céntimos.
final class SpokenAmount {
  const SpokenAmount._();

  static int? tryParse(String raw) {
    final text = _fold(raw);
    if (text.isEmpty) return null;

    return InputSanitizer.centimos(
      _onlyCentimos(text) ?? _solesWithCentimos(text) ?? _wholeSoles(text),
    );
  }

  /// "cincuenta céntimos", "50 centavos".
  static int? _onlyCentimos(String text) {
    final match = _centimosEnding.firstMatch(text);
    if (match == null) return null;
    final head = text.substring(0, match.start).trim();
    if (head.isEmpty) return null;
    return _smallNumber(head);
  }

  /// "un sol cincuenta", "dos soles con treinta", "1 sol 50".
  static int? _solesWithCentimos(String text) {
    final match = _solWord.firstMatch(text);
    if (match == null) return null;

    final head = text.substring(0, match.start).trim();
    var tail = text.substring(match.end).trim();
    if (head.isEmpty || tail.isEmpty) return null;

    tail = tail.replaceFirst(RegExp(r'^(?:con|y)\s+'), '').trim();
    tail = tail.replaceFirst(_centimosEnding, '').trim();
    if (tail.isEmpty) return null;

    final soles = _soles(head);
    final cents = _smallNumber(tail);
    if (soles == null || cents == null || cents > 99) return null;
    return soles * centsPerSol + cents;
  }

  /// "cinco mil", "5000", "20 soles", "1.50".
  static int? _wholeSoles(String text) {
    final clean = text
        .replaceAll(RegExp(r'\b(?:sol|soles|peso|pesos)\b'), ' ')
        .replaceAll(RegExp(r'\bde\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'^[\d.,]+$').hasMatch(clean)) return parseSolesText(clean);

    final soles = _soles(clean);
    if (soles == null) return null;
    return soles * centsPerSol;
  }

  /// Soles enteros dichos con cifras o con palabras.
  static int? _soles(String text) {
    final compact = text.replaceAll(RegExp(r'[.\s,]'), '');
    if (RegExp(r'^\d+$').hasMatch(compact) && !text.contains('mil')) {
      return int.tryParse(compact);
    }

    final nMil = RegExp(r'^(\d+)\s*mil$').firstMatch(text);
    if (nMil != null) {
      final n = int.tryParse(nMil.group(1)!);
      return n == null ? null : n * 1000;
    }

    return _fromWords(text);
  }

  /// Los céntimos: "cincuenta" o "50".
  static int? _smallNumber(String text) {
    if (RegExp(r'^\d{1,2}$').hasMatch(text)) return int.tryParse(text);
    return _belowThousand(text.split(' '));
  }

  static final _centimosEnding = RegExp(
    r'\s*\b(?:centimos?|centavos?)\b\s*$',
  );

  static final _solWord = RegExp(r'\b(?:sol|soles)\b');

  static String _fold(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9ñ\s.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _fromWords(String text) {
    final cleaned = text.replaceAll(RegExp(r'\by\b'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;

    if (!cleaned.contains('mil')) {
      return _belowThousand(cleaned.split(' '));
    }

    final parts = cleaned.split(RegExp(r'\bmil\b'));
    if (parts.length > 2) return null;
    final leftRaw = parts[0].trim();
    final rightRaw = parts.length > 1 ? parts[1].trim() : '';

    var thousands = 1;
    if (leftRaw.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(leftRaw)) {
        thousands = int.parse(leftRaw);
      } else {
        final parsed = _belowThousand(leftRaw.split(' '));
        if (parsed == null || parsed == 0) return null;
        thousands = parsed;
      }
    }

    var rest = 0;
    if (rightRaw.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(rightRaw)) {
        rest = int.parse(rightRaw);
      } else {
        final parsed = _belowThousand(rightRaw.split(' '));
        if (parsed == null) return null;
        rest = parsed;
      }
    }

    return thousands * 1000 + rest;
  }

  static const _units = {
    'cero': 0,
    'un': 1,
    'uno': 1,
    'una': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
  };

  static const _teens = {
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
  };

  static const _tens = {
    'veinte': 20,
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  };

  static const _hundreds = {
    'cien': 100,
    'ciento': 100,
    'doscientos': 200,
    'trescientos': 300,
    'cuatrocientos': 400,
    'quinientos': 500,
    'seiscientos': 600,
    'setecientos': 700,
    'ochocientos': 800,
    'novecientos': 900,
  };

  static int? _belowThousand(List<String> tokens) {
    final words = tokens.where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return 0;
    var total = 0;
    for (final word in words) {
      if (_hundreds.containsKey(word)) {
        total += _hundreds[word]!;
        continue;
      }
      if (_teens.containsKey(word)) {
        total += _teens[word]!;
        continue;
      }
      if (word.startsWith('veinti') && word.length > 6) {
        final unit = _units[word.substring(6)];
        if (unit == null || unit == 0) return null;
        total += 20 + unit;
        continue;
      }
      if (_tens.containsKey(word)) {
        total += _tens[word]!;
        continue;
      }
      if (_units.containsKey(word)) {
        total += _units[word]!;
        continue;
      }
      return null;
    }
    if (total < 0 || total > 999) return null;
    return total;
  }
}
