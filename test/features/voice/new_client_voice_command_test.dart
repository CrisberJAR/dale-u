import 'package:dale_u/features/voice/domain/new_client_voice_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NewClientVoiceCommand', () {
    test('entiende nuevo cliente y el nombre', () {
      final command = NewClientVoiceCommand.tryParse('nuevo cliente María');
      expect(command, isNotNull);
      expect(command!.name, 'María');
      expect(command.phone, isEmpty);
      expect(command.hasName, isTrue);
    });

    test('entiende agregar cliente con teléfono', () {
      final command = NewClientVoiceCommand.tryParse(
        'agregar cliente doña María teléfono 300 123 4567',
      );
      expect(command!.name, 'Doña María');
      expect(command.phone, '300 123 4567');
    });

    test('toma dígitos al final como teléfono', () {
      final command = NewClientVoiceCommand.tryParse(
        'nuevo cliente Juan Pérez 3001234567',
      );
      expect(command!.name, 'Juan Pérez');
      expect(command.phone, '3001234567');
    });

    test('quiere un nuevo cliente llamado', () {
      final command = NewClientVoiceCommand.tryParse(
        'quiero un nuevo cliente llamado Pedro',
      );
      expect(command!.name, 'Pedro');
    });

    test('comando sin nombre', () {
      final command = NewClientVoiceCommand.tryParse('nuevo cliente');
      expect(command, isNotNull);
      expect(command!.hasName, isFalse);
    });

    test('no confunde otras frases con un alta', () {
      expect(NewClientVoiceCommand.tryParse('hola María'), isNull);
      expect(NewClientVoiceCommand.tryParse('fiado a María'), isNull);
      expect(NewClientVoiceCommand.tryParse('anotar pago a Juan'), isNull);
      expect(NewClientVoiceCommand.tryParse('cuánto debe María'), isNull);
      expect(NewClientVoiceCommand.tryParse('buscar María'), isNull);
    });
  });
}
