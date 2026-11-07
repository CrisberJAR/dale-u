import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/voice/domain/debt_voice_command.dart';
import 'package:dale_u/features/voice/domain/ledger_voice_command.dart';
import 'package:dale_u/features/voice/domain/new_client_voice_command.dart';
import 'package:dale_u/features/voice/domain/search_voice_command.dart';
import 'package:dale_u/features/voice/domain/spoken_amount.dart';
import 'package:dale_u/features/voice/presentation/pages/voice_commands_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// La chuleta no puede prometer frases que el teléfono no entiende.
void main() {
  List<String> examplesOf(String title) {
    return voiceCommandGroups
        .firstWhere((group) => group.title == title)
        .examples;
  }

  test('los ejemplos de cliente nuevo se entienden y traen nombre', () {
    for (final phrase in examplesOf('Apuntar un cliente nuevo')) {
      final parsed = NewClientVoiceCommand.tryParse(phrase);
      expect(parsed, isNotNull, reason: phrase);
      expect(parsed!.hasName, isTrue, reason: phrase);
    }
  });

  test('los ejemplos de fiado se entienden con nombre y monto', () {
    for (final phrase in examplesOf('Anotar un fiado')) {
      final parsed = LedgerVoiceCommand.tryParse(phrase);
      expect(parsed, isNotNull, reason: phrase);
      expect(parsed!.kind, MovementKind.fiado, reason: phrase);
      expect(parsed.isComplete, isTrue, reason: phrase);
    }
  });

  test('los ejemplos de pago se entienden con nombre y monto', () {
    for (final phrase in examplesOf('Anotar un pago')) {
      final parsed = LedgerVoiceCommand.tryParse(phrase);
      expect(parsed, isNotNull, reason: phrase);
      expect(parsed!.kind, MovementKind.pago, reason: phrase);
      expect(parsed.isComplete, isTrue, reason: phrase);
    }
  });

  test('los ejemplos de consulta se entienden y traen nombre', () {
    for (final phrase in examplesOf('Preguntar cuánto debe')) {
      final parsed = DebtVoiceCommand.tryParse(phrase);
      expect(parsed, isNotNull, reason: phrase);
      expect(parsed!.hasName, isTrue, reason: phrase);
    }
  });

  test('los ejemplos de búsqueda llegan al buscador', () {
    for (final phrase in examplesOf('Buscar en la lista')) {
      final parsed = SearchVoiceCommand.tryParse(phrase);
      if (parsed != null) {
        expect(parsed.hasQuery, isTrue, reason: phrase);
        continue;
      }
      // Un nombre suelto también sirve de búsqueda.
      expect(SearchVoiceCommand.asBareQuery(phrase), isNotNull, reason: phrase);
    }
  });

  test('los ejemplos de montos se convierten a soles', () {
    for (final phrase in examplesOf('Cómo decir el dinero')) {
      expect(SpokenAmount.tryParse(phrase), isNotNull, reason: phrase);
    }
  });

  test('los ejemplos de céntimos dan menos de diez soles', () {
    for (final phrase in examplesOf('Céntimos')) {
      final cents = SpokenAmount.tryParse(phrase);
      expect(cents, isNotNull, reason: phrase);
      expect(cents! % 100, isNot(0), reason: phrase);
      expect(cents, lessThan(1000), reason: phrase);
    }
  });
}
