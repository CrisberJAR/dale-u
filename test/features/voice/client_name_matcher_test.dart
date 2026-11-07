import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/voice/domain/client_name_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

Client _client(String id, String name) {
  return Client(
    id: id,
    vendorUid: 'v1',
    name: name,
    phone: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

void main() {
  test('encuentra por nombre parcial sin importar acentos', () {
    final match = ClientNameMatcher.match(
      [_client('1', 'Doña María')],
      'maria',
    );
    expect(match, isA<ClientNameUnique>());
    expect((match as ClientNameUnique).client.id, '1');
  });

  test('avisa si hay varias coincidencias', () {
    final match = ClientNameMatcher.match(
      [_client('1', 'María López'), _client('2', 'María Pérez')],
      'María',
    );
    expect(match, isA<ClientNameAmbiguous>());
  });

  test('no encuentra si no está en la lista', () {
    final match = ClientNameMatcher.match(
      [_client('1', 'Juan')],
      'María',
    );
    expect(match, isA<ClientNameNone>());
  });
}
