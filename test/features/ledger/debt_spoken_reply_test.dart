import 'package:dale_u/features/ledger/domain/ledger_spoken.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dice el saldo, el cero y el a favor en soles', () {
    expect(
      debtSpokenReply(clientName: 'María', balance: 500000),
      'María debe 5000 soles.',
    );
    expect(
      debtSpokenReply(clientName: 'Juan', balance: 0),
      'Juan no debe nada.',
    );
    expect(
      debtSpokenReply(clientName: 'Pedro', balance: -150000),
      'Pedro tiene 1500 soles a favor.',
    );
  });

  test('dice los céntimos en cristiano', () {
    expect(
      debtSpokenReply(clientName: 'Ander', balance: 150),
      'Ander debe 1 sol con 50 céntimos.',
    );
    expect(
      debtSpokenReply(clientName: 'Rosa', balance: 50),
      'Rosa debe 50 céntimos.',
    );
    expect(
      debtSpokenReply(clientName: 'Luis', balance: 230),
      'Luis debe 2 soles con 30 céntimos.',
    );
  });
}
