import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/statement/data/statement_pdf.dart';
import 'package:dale_u/features/statement/domain/statement.dart';
import 'package:dale_u/features/statement/domain/whatsapp_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

Movement _move(String id, MovementKind kind, int cents, {bool voided = false}) {
  return Movement(
    id: id,
    vendorUid: 'vend1',
    clientId: 'client1',
    kind: kind,
    amountCents: cents,
    occurredAt: DateTime.utc(2026, 9, 1, 15),
    createdAt: DateTime.utc(2026, 9, 1, 15),
    voided: voided,
  );
}

void main() {
  group('WhatsAppReminder.normalizePhone', () {
    test('celular peruano de 9 dígitos lleva 51', () {
      expect(WhatsAppReminder.normalizePhone('987 654 321'), '51987654321');
    });

    test('si ya trae +51 se respeta', () {
      expect(WhatsAppReminder.normalizePhone('+51 987-654-321'), '51987654321');
    });

    test('sin número sirve vacío: WhatsApp deja elegir el contacto', () {
      expect(WhatsAppReminder.normalizePhone(''), '');
      expect(WhatsAppReminder.normalizePhone('123'), '');
    });
  });

  group('WhatsAppReminder.message', () {
    test('con deuda: monto, enlace y gracias', () {
      final text = WhatsAppReminder.message(
        clientName: 'María López',
        vendorName: 'Don Pan',
        balanceCents: 1250,
        link: 'https://x.web.app/e/abc',
      );
      expect(text, contains('Hola María'));
      expect(text, contains('Don Pan'));
      expect(text, contains('S/ 12.50'));
      expect(text, contains('https://x.web.app/e/abc'));
    });

    test('al día no habla de deuda', () {
      final text = WhatsAppReminder.message(
        clientName: 'Rosa',
        vendorName: '',
        balanceCents: 0,
      );
      expect(text, contains('Estás al día'));
      expect(text, isNot(contains('pendiente')));
    });

    test('el enlace va codificado en wa.me', () {
      final uri = WhatsAppReminder.uri(phone: '987654321', text: 'Hola & más');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/51987654321');
      expect(uri.queryParameters['text'], 'Hola & más');
    });
  });

  group('Statement', () {
    test('lo anulado no aparece ni suma', () {
      final statement = Statement(
        vendorName: 'Don Pan',
        clientName: 'María',
        movements: [
          _move('m1-aaaaaaaa', MovementKind.fiado, 1000),
          _move('m2-aaaaaaaa', MovementKind.pago, 300),
          _move('m3-aaaaaaaa', MovementKind.fiado, 5000, voided: true),
        ],
        generatedAt: DateTime.utc(2026, 9, 2),
      );
      expect(statement.movements, hasLength(2));
      expect(statement.balanceCents, 700);
      expect(statement.balanceLine, 'Debe S/ 7.00');
    });

    test('el PDF se arma con tildes y ñ', () async {
      final statement = Statement(
        vendorName: 'Panadería Ñaña',
        clientName: 'José Muñoz',
        movements: [_move('m1-aaaaaaaa', MovementKind.fiado, 1550)],
        generatedAt: DateTime.utc(2026, 9, 2),
      );
      final bytes = await StatementPdf.build(statement);
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        StatementPdf.fileName(statement),
        'estado-de-cuenta-jose-munoz.pdf',
      );
    });
  });
}
