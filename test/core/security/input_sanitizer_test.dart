import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InputSanitizer', () {
    test('elimina caracteres de control y recorta el nombre', () {
      expect(
        InputSanitizer.displayName('  Ana\nPérez${String.fromCharCode(7)}  '),
        'AnaPérez',
      );
      expect(InputSanitizer.displayName(''), 'Usuario');
      expect(InputSanitizer.displayName(null), 'Usuario');
      expect(InputSanitizer.displayName('a' * 90).length, 80);
    });

    test('normaliza email y rechaza urls inseguras', () {
      expect(InputSanitizer.email('  ana@pan.com  '), 'ana@pan.com');
      expect(InputSanitizer.photoUrl('http://malicioso.local/x'), isNull);
      expect(
        InputSanitizer.photoUrl('https://lh3.googleusercontent.com/a/x'),
        'https://lh3.googleusercontent.com/a/x',
      );
    });

    test('acepta UID seguros y rechaza claves peligrosas', () {
      expect(InputSanitizer.uid('abc-123_XYZ'), 'abc-123_XYZ');
      expect(InputSanitizer.uid('../role'), isNull);
      expect(InputSanitizer.uid('uid;drop'), isNull);
      expect(InputSanitizer.uid(''), isNull);
    });

    test('valida nombre de cliente y limpia teléfono', () {
      expect(InputSanitizer.personName('  Doña María  '), 'Doña María');
      expect(InputSanitizer.personName('a'), isNull);
      expect(InputSanitizer.phone('300 123 4567<script>'), '300 123 4567');
      expect(InputSanitizer.phone('sin numeros'), '');
    });

    test('limpia texto dictado', () {
      expect(
        InputSanitizer.spokenText('  Hola   María  '),
        'Hola María',
      );
      expect(InputSanitizer.spokenText('a' * 350).length, 280);
      expect(InputSanitizer.centimos(150), 150);
      expect(InputSanitizer.centimos(0), isNull);
      expect(InputSanitizer.centimos(2000000000), isNull);
      expect(InputSanitizer.latitude(-12.05), -12.05);
      expect(InputSanitizer.latitude(91), isNull);
      expect(InputSanitizer.longitude(-77.04), -77.04);
      expect(InputSanitizer.longitude(200), isNull);
    });

    test('limpia el aviso a clientes y rechaza vacío', () {
      expect(InputSanitizer.notice('  Hoy no hay pan  '), 'Hoy no hay pan');
      expect(InputSanitizer.notice('a'), isNull);
      expect(InputSanitizer.notice('x' * 250)!.length, 200);
    });
  });
}
