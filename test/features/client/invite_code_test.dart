import 'package:dale_u/features/client/domain/invite_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera 6 caracteres del alfabeto seguro', () {
    final code = InviteCode.generate();
    expect(code.length, 6);
    expect(InviteCode.parse(code), code);
  });

  test('acepta minúsculas y recorta espacios', () {
    expect(InviteCode.parse(' ab-c23x '), isNotNull);
    expect(InviteCode.parse('hola'), isNull);
    expect(InviteCode.parse('000000'), isNull);
  });
}
