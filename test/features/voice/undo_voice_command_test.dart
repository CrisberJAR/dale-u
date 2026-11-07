import 'package:dale_u/features/voice/domain/undo_voice_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('entiende las formas de deshacer', () {
    for (final phrase in [
      'deshacer',
      'Deshaz',
      'deshazlo',
      'me equivoqué',
      'borra el último',
      'anula el ultimo fiado',
      'cancela el último pago',
      'Quita lo último',
    ]) {
      expect(UndoVoiceCommand.matches(phrase), isTrue, reason: phrase);
    }
  });

  test('no se traga otros comandos', () {
    for (final phrase in [
      'fiado a María 10 soles',
      'borra a María',
      'cuánto debe el último cliente',
      'pago de Rosa 5',
    ]) {
      expect(UndoVoiceCommand.matches(phrase), isFalse, reason: phrase);
    }
  });
}
