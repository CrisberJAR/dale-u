import 'dart:math';

/// Código corto para que el comprador vea su deuda. Sin 0/O ni 1/I.
final class InviteCode {
  const InviteCode._();

  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 6;

  static final pattern = RegExp('^[$alphabet]{$length}\$');

  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[rng.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  static String? parse(String? raw) {
    final cleaned = (raw ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '');
    if (!pattern.hasMatch(cleaned)) return null;
    return cleaned;
  }
}
