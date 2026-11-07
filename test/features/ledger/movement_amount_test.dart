import 'package:dale_u/features/ledger/data/movement_amount.dart';
import 'package:flutter_test/flutter_test.dart';

/// En la nube conviven documentos viejos (soles) y nuevos (céntimos).
void main() {
  test('un documento nuevo se lee tal cual', () {
    expect(readAmountCents({'amountCents': 150}), 150);
  });

  test('un documento viejo en soles se convierte a céntimos', () {
    expect(readAmountCents({'amountPesos': 5000}), 500000);
  });

  test('si trae los dos, manda el nuevo', () {
    expect(readAmountCents({'amountCents': 150, 'amountPesos': 5000}), 150);
  });

  test('sin monto no hay movimiento', () {
    expect(readAmountCents({'kind': 'fiado'}), isNull);
  });
}
