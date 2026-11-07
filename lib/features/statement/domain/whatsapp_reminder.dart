import 'package:dale_u/core/format/money.dart';

/// Arma el enlace de WhatsApp para recordar el cobro. Sin servidor: abre
/// el chat del cliente con el mensaje ya escrito y el vendedor decide enviar.
final class WhatsAppReminder {
  const WhatsAppReminder._();

  /// Código de Perú.
  static const countryCode = '51';

  /// Número listo para wa.me (solo dígitos, con 51). Vacío si no sirve:
  /// WhatsApp abre igual y el vendedor elige el contacto.
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 9 && digits.startsWith('9')) {
      return '$countryCode$digits';
    }
    if (digits.length == 11 && digits.startsWith('${countryCode}9')) {
      return digits;
    }
    // Otro país o fijo: si ya trae código (10 a 15 dígitos), se respeta.
    if (digits.length >= 10 && digits.length <= 15 && !digits.startsWith('0')) {
      return digits;
    }
    return '';
  }

  static String message({
    required String clientName,
    required String vendorName,
    required int balanceCents,
    String? link,
  }) {
    final firstName = clientName.trim().split(RegExp(r'\s+')).first;
    final from = vendorName.trim().isEmpty ? 'tu panadero' : vendorName.trim();
    final buffer = StringBuffer('Hola $firstName, te saluda $from. ');
    if (balanceCents > 0) {
      buffer.write(
        'Te recuerdo que tu saldo pendiente es de S/ ${formatSoles(balanceCents)}.',
      );
    } else if (balanceCents < 0) {
      buffer.write(
        'Tienes S/ ${formatSoles(-balanceCents)} a tu favor.',
      );
    } else {
      buffer.write('Estás al día, ¡gracias!');
    }
    if (link != null && link.isNotEmpty) {
      buffer.write(' Aquí puedes ver el detalle: $link');
    }
    if (balanceCents > 0) buffer.write(' ¡Gracias!');
    return buffer.toString();
  }

  static Uri uri({required String phone, required String text}) {
    final number = normalizePhone(phone);
    return Uri.https('wa.me', number.isEmpty ? '/' : '/$number', {
      'text': text,
    });
  }
}
