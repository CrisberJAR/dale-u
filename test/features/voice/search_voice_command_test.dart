import 'package:dale_u/features/voice/domain/debt_voice_command.dart';
import 'package:dale_u/features/voice/domain/ledger_voice_command.dart';
import 'package:dale_u/features/voice/domain/new_client_voice_command.dart';
import 'package:dale_u/features/voice/domain/search_voice_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchVoiceCommand', () {
    test('entiende buscar y el nombre', () {
      final command = SearchVoiceCommand.tryParse('buscar María');
      expect(command, isNotNull);
      expect(command!.query, 'María');
      expect(command.hasQuery, isTrue);
    });

    test('entiende busca a y encuentra cliente', () {
      expect(SearchVoiceCommand.tryParse('busca a Juan')!.query, 'Juan');
      expect(
        SearchVoiceCommand.tryParse('buscar cliente doña María')!.query,
        'Doña María',
      );
    });

    test('buscar a con el conector delante del nombre', () {
      expect(SearchVoiceCommand.tryParse('buscar a Juan')!.query, 'Juan');
      expect(SearchVoiceCommand.tryParse('buscar al señor Luis')!.query, 'Señor Luis');
      expect(SearchVoiceCommand.tryParse('búscame a Delia')!.query, 'Delia');
    });

    test('no se come la primera letra del nombre', () {
      expect(SearchVoiceCommand.tryParse('buscar Ander')!.query, 'Ander');
      expect(SearchVoiceCommand.tryParse('buscar Melissa')!.query, 'Melissa');
      expect(SearchVoiceCommand.tryParse('buscar Delia')!.query, 'Delia');
    });

    test('pide el nombre si falta', () {
      final command = SearchVoiceCommand.tryParse('buscar');
      expect(command, isNotNull);
      expect(command!.hasQuery, isFalse);
    });

    test('un nombre suelto sirve para la barra', () {
      expect(SearchVoiceCommand.asBareQuery('María'), 'María');
      expect(SearchVoiceCommand.asBareQuery('doña ana'), 'Doña Ana');
    });

    test('una frase con monto o fiado no acaba en el buscador', () {
      expect(SearchVoiceCommand.asBareQuery('Ander 10 soles de fiado'), isNull);
      expect(SearchVoiceCommand.asBareQuery('María mil pesos'), isNull);
      expect(SearchVoiceCommand.asBareQuery('el cliente nuevo'), isNull);
      expect(SearchVoiceCommand.asBareQuery('3001234567'), isNull);
      expect(
        SearchVoiceCommand.asBareQuery('hoy hace mucho calor en la ruta'),
        isNull,
      );
    });

    test('no confunde fiado, alta ni consulta de deuda', () {
      expect(SearchVoiceCommand.tryParse('fiado a María 5000'), isNull);
      expect(SearchVoiceCommand.tryParse('nuevo cliente María'), isNull);
      expect(SearchVoiceCommand.tryParse('cuánto debe María'), isNull);
      expect(NewClientVoiceCommand.tryParse('buscar María'), isNull);
      expect(LedgerVoiceCommand.tryParse('buscar María'), isNull);
      expect(DebtVoiceCommand.tryParse('buscar María'), isNull);
    });
  });
}
