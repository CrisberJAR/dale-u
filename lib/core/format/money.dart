import 'package:dale_u/core/time/peru_time.dart';

/// El dinero se guarda en céntimos. 150 son S/ 1.50.
const centsPerSol = 100;

/// Formato peruano para pantalla: 150 -> 1.50, 500000 -> 5,000.00.
String formatSoles(int cents) {
  final sign = cents < 0 ? '-' : '';
  final total = cents.abs();
  final digits = (total ~/ centsPerSol).toString();
  final rest = (total % centsPerSol).toString().padLeft(2, '0');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return '$sign$buffer.$rest';
}

/// Lee un monto escrito. El último separador manda: con una o dos cifras
/// detrás son céntimos (1.50), con tres es separador de miles (5.000).
int? parseSolesText(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'[^\d.,]'), '')
      .replaceAll(' ', '')
      .trim();
  if (cleaned.isEmpty) return null;

  final lastSeparator = cleaned.lastIndexOf(RegExp(r'[.,]'));
  var wholeText = cleaned;
  var centsText = '';
  if (lastSeparator >= 0) {
    final tail = cleaned.substring(lastSeparator + 1);
    if (tail.length == 1 || tail.length == 2) {
      wholeText = cleaned.substring(0, lastSeparator);
      centsText = tail.padRight(2, '0');
    }
  }

  final whole = int.tryParse(wholeText.replaceAll(RegExp(r'[.,]'), '')) ?? 0;
  final cents = centsText.isEmpty ? 0 : int.tryParse(centsText);
  if (cents == null) return null;
  return whole * centsPerSol + cents;
}

/// Cómo se dice en voz alta: 150 -> "1 sol con 50 céntimos".
String spokenSoles(int cents) {
  final sign = cents < 0 ? 'menos ' : '';
  final total = cents.abs();
  final whole = total ~/ centsPerSol;
  final rest = total % centsPerSol;
  final unit = whole == 1 ? 'sol' : 'soles';
  if (rest == 0) return '$sign$whole $unit';
  if (whole == 0) return '$sign$rest céntimos';
  return '$sign$whole $unit con $rest céntimos';
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Sello de fecha/hora en hora de Perú.
String spokenStamp(DateTime at) {
  final peru = toPeru(at);
  final hour = peru.hour.toString().padLeft(2, '0');
  final minute = peru.minute.toString().padLeft(2, '0');
  return '${peru.day} de ${_months[peru.month - 1]} a las $hour:$minute';
}

String spokenDay(DateTime at) {
  final peru = toPeru(at);
  return '${peru.day} de ${_months[peru.month - 1]}';
}

String spokenDateKey(int dateKey) => spokenDay(fromPeruDateKey(dateKey));

String peruDateLabel(DateTime at) {
  final peru = toPeru(at);
  final day = peru.day.toString().padLeft(2, '0');
  final month = peru.month.toString().padLeft(2, '0');
  return '$day/$month/${peru.year}';
}

String peruDateKeyLabel(int dateKey) => peruDateLabel(fromPeruDateKey(dateKey));

String peruTimeLabel(DateTime at) {
  final peru = toPeru(at);
  final hour = peru.hour.toString().padLeft(2, '0');
  final minute = peru.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
