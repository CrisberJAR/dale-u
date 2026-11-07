import 'package:dale_u/features/voice/domain/debt_voice_command.dart';
import 'package:dale_u/features/voice/domain/ledger_voice_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebtVoiceCommand', () {
    test('entiende cuánto debe y el nombre', () {
      final command = DebtVoiceCommand.tryParse('cuánto debe María');
      expect(command, isNotNull);
      expect(command!.name, 'María');
      expect(command.hasName, isTrue);
    });

    test('entiende saldo de y deuda de', () {
      expect(DebtVoiceCommand.tryParse('saldo de Juan')!.name, 'Juan');
      expect(
        DebtVoiceCommand.tryParse('cuál es la deuda de doña María')!.name,
        'Doña María',
      );
    });

    test('no se come la primera letra del nombre', () {
      expect(DebtVoiceCommand.tryParse('cuánto debe Delia')!.name, 'Delia');
      expect(DebtVoiceCommand.tryParse('saldo Delia')!.name, 'Delia');
      expect(DebtVoiceCommand.tryParse('cuánto deben Ander')!.name, 'Ander');
    });

    test('pide el nombre si falta', () {
      final command = DebtVoiceCommand.tryParse('cuánto debe');
      expect(command, isNotNull);
      expect(command!.hasName, isFalse);
    });

    test('no confunde fiado ni alta de cliente', () {
      expect(DebtVoiceCommand.tryParse('fiado a María 5000'), isNull);
      expect(DebtVoiceCommand.tryParse('nuevo cliente María'), isNull);
      expect(LedgerVoiceCommand.tryParse('cuánto debe María'), isNull);
    });
  });
}
