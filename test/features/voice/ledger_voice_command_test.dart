import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/voice/domain/ledger_voice_command.dart';
import 'package:dale_u/features/voice/domain/spoken_amount.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpokenAmount', () {
    test('entiende números y miles en céntimos', () {
      expect(SpokenAmount.tryParse('5000'), 500000);
      expect(SpokenAmount.tryParse('5.000'), 500000);
      expect(SpokenAmount.tryParse('5 mil'), 500000);
      expect(SpokenAmount.tryParse('5000 soles'), 500000);
      expect(SpokenAmount.tryParse('cinco mil'), 500000);
      expect(SpokenAmount.tryParse('dos mil quinientos'), 250000);
      expect(SpokenAmount.tryParse('mil'), 100000);
      expect(SpokenAmount.tryParse('20 soles'), 2000);
    });

    test('entiende céntimos dichos como se hablan', () {
      expect(SpokenAmount.tryParse('un sol cincuenta'), 150);
      expect(SpokenAmount.tryParse('un sol con cincuenta'), 150);
      expect(SpokenAmount.tryParse('1 sol 50'), 150);
      expect(SpokenAmount.tryParse('dos soles con treinta'), 230);
      expect(SpokenAmount.tryParse('cincuenta céntimos'), 50);
      expect(SpokenAmount.tryParse('80 centavos'), 80);
      expect(SpokenAmount.tryParse('tres soles con veinticinco'), 325);
    });

    test('entiende el monto escrito con punto', () {
      expect(SpokenAmount.tryParse('1.50'), 150);
      expect(SpokenAmount.tryParse('1.5'), 150);
      expect(SpokenAmount.tryParse('12.30 soles'), 1230);
    });

    test('rechaza textos que no son monto', () {
      expect(SpokenAmount.tryParse('María'), isNull);
      expect(SpokenAmount.tryParse(''), isNull);
      expect(SpokenAmount.tryParse('0'), isNull);
    });
  });

  group('LedgerVoiceCommand', () {
    test('entiende fiado con monto', () {
      final command = LedgerVoiceCommand.tryParse('fiado a María 5000');
      expect(command, isNotNull);
      expect(command!.kind, MovementKind.fiado);
      expect(command.name, 'María');
      expect(command.amountCents, 500000);
      expect(command.isComplete, isTrue);
    });

    test('entiende anotar pago con mil en palabras', () {
      final command = LedgerVoiceCommand.tryParse(
        'anotar pago de Juan cinco mil',
      );
      expect(command!.kind, MovementKind.pago);
      expect(command.name, 'Juan');
      expect(command.amountCents, 500000);
    });

    test('pago seco: solo pago, nombre y monto', () {
      final maria = LedgerVoiceCommand.tryParse('pago maría 100');
      expect(maria!.kind, MovementKind.pago);
      expect(maria.name, 'María');
      expect(maria.amountCents, 10000);

      final juan = LedgerVoiceCommand.tryParse('pago juan 200');
      expect(juan!.kind, MovementKind.pago);
      expect(juan.name, 'Juan');
      expect(juan.amountCents, 20000);
    });

    test('entiende pagó con tilde igual que pago', () {
      final seco = LedgerVoiceCommand.tryParse('pagó maría 100');
      expect(seco, isNotNull);
      expect(seco!.kind, MovementKind.pago);
      expect(seco.name, 'María');
      expect(seco.amountCents, 10000);

      final conDe = LedgerVoiceCommand.tryParse('pagó a Juan cinco mil');
      expect(conDe!.kind, MovementKind.pago);
      expect(conDe.name, 'Juan');
      expect(conDe.amountCents, 500000);

      final alFinal = LedgerVoiceCommand.tryParse('María 15 soles de pagó');
      expect(alFinal!.kind, MovementKind.pago);
      expect(alFinal.name, 'María');
      expect(alFinal.amountCents, 1500);
    });

    test('no se come la primera letra del nombre', () {
      final pago = LedgerVoiceCommand.tryParse('pago ander 50');
      expect(pago!.name, 'Ander');
      expect(pago.amountCents, 5000);

      final fiado = LedgerVoiceCommand.tryParse('fiado ander 20');
      expect(fiado!.name, 'Ander');
      expect(fiado.amountCents, 2000);

      final conAcento = LedgerVoiceCommand.tryParse('cobré a Pedro 30');
      expect(conAcento!.kind, MovementKind.pago);
      expect(conAcento.name, 'Pedro');
    });

    test('pide monto si falta', () {
      final command = LedgerVoiceCommand.tryParse('fiado a María');
      expect(command, isNotNull);
      expect(command!.hasName, isTrue);
      expect(command.amountCents, isNull);
    });

    test('entiende el orden natural: nombre, monto y fiado al final', () {
      final fiado = LedgerVoiceCommand.tryParse('Ander 10 soles de fiado');
      expect(fiado, isNotNull);
      expect(fiado!.kind, MovementKind.fiado);
      expect(fiado.name, 'Ander');
      expect(fiado.amountCents, 1000);
      expect(fiado.isComplete, isTrue);

      final pago = LedgerVoiceCommand.tryParse('María cinco mil de pago');
      expect(pago!.kind, MovementKind.pago);
      expect(pago.name, 'María');
      expect(pago.amountCents, 500000);
    });

    test('entiende céntimos en la frase completa', () {
      final fiado = LedgerVoiceCommand.tryParse('fiado a Ander un sol cincuenta');
      expect(fiado, isNotNull);
      expect(fiado!.name, 'Ander');
      expect(fiado.amountCents, 150);

      final pago = LedgerVoiceCommand.tryParse('pago María 1.50');
      expect(pago!.name, 'María');
      expect(pago.amountCents, 150);
    });

    test('sin monto al final no lo toma como fiado', () {
      expect(LedgerVoiceCommand.tryParse('cuánto tiene de fiado'), isNull);
      expect(LedgerVoiceCommand.tryParse('esto es un fiado'), isNull);
    });

    test('no confunde nuevo cliente ni consultas', () {
      expect(LedgerVoiceCommand.tryParse('nuevo cliente María'), isNull);
      expect(LedgerVoiceCommand.tryParse('cuánto debe María'), isNull);
      expect(LedgerVoiceCommand.tryParse('buscar María'), isNull);
      expect(LedgerVoiceCommand.tryParse('hola María'), isNull);
    });
  });
}
