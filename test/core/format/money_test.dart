import 'package:dale_u/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatea céntimos como se escribe en Perú', () {
    expect(formatSoles(150), '1.50');
    expect(formatSoles(50), '0.50');
    expect(formatSoles(500000), '5,000.00');
    expect(formatSoles(123456789), '1,234,567.89');
    expect(formatSoles(0), '0.00');
    expect(formatSoles(-150), '-1.50');
  });

  test('lee lo que se escribe a mano', () {
    expect(parseSolesText('1.50'), 150);
    expect(parseSolesText('1,50'), 150);
    expect(parseSolesText('1.5'), 150);
    expect(parseSolesText('5000'), 500000);
    expect(parseSolesText('5,000.00'), 500000);
    expect(parseSolesText('S/ 12.30'), 1230);
    expect(parseSolesText(''), isNull);
  });

  test('tres cifras detrás del punto son miles, no céntimos', () {
    expect(parseSolesText('5.000'), 500000);
  });

  test('lo dice en voz alta en cristiano', () {
    expect(spokenSoles(150), '1 sol con 50 céntimos');
    expect(spokenSoles(100), '1 sol');
    expect(spokenSoles(230), '2 soles con 30 céntimos');
    expect(spokenSoles(50), '50 céntimos');
    expect(spokenSoles(500000), '5000 soles');
  });
}
