import 'package:dale_u/features/client/domain/client_roster.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:flutter_test/flutter_test.dart';

Client _client(
  String id,
  String name, {
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final created = createdAt ?? DateTime(2026, 1, 1);
  return Client(
    id: id,
    vendorUid: 'v1',
    name: name,
    phone: '',
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  final maria = _client('m', 'María');
  final juan = _client(
    'j',
    'Juan',
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
  final ana = _client(
    'a',
    'Ana',
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );
  final pedro = _client('p', 'Pedro');

  const balances = {
    'm': 5000,
    'j': 0,
    'a': 0,
    'p': -1500,
  };

  test('filtra por nombre en tiempo real sin importar acentos', () {
    final visible = ClientRoster.apply(
      clients: [maria, juan, ana],
      balances: balances,
      query: 'maria',
      filter: ClientRosterFilter.all,
    );
    expect(visible.map((client) => client.id), ['m']);
  });

  test('con deuda solo deja saldo pendiente', () {
    final visible = ClientRoster.apply(
      clients: [maria, juan, ana, pedro],
      balances: balances,
      query: '',
      filter: ClientRosterFilter.withDebt,
    );
    expect(visible.map((client) => client.id), ['m']);
  });

  test('al día incluye cero y a favor', () {
    final visible = ClientRoster.apply(
      clients: [maria, juan, ana, pedro],
      balances: balances,
      query: '',
      filter: ClientRosterFilter.settled,
    );
    expect(visible.map((client) => client.id), ['j', 'a', 'p']);
  });

  test('pone primero a quienes deben y luego la actividad reciente', () {
    final visible = ClientRoster.apply(
      clients: [ana, juan, maria],
      balances: balances,
      query: '',
      filter: ClientRosterFilter.all,
    );
    expect(visible.map((client) => client.id), ['m', 'j', 'a']);
  });
}
