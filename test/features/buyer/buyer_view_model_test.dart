import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/buyer/data/buyer_remote_datasource.dart';
import 'package:dale_u/features/buyer/data/linked_account_store.dart';
import 'package:dale_u/features/buyer/domain/buyer_exception.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/buyer/presentation/viewmodels/buyer_view_model.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AuthRepository {
  @override
  Stream<UserSession?> observeAuthState() {
    return Stream<UserSession?>.value(
      const UserSession(uid: 'buyer1', email: 'a@b.com', displayName: 'Ana'),
    );
  }

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

class _FakeInbox implements PanInboxRemote {
  final sent = <({
    String vendorUid,
    String buyerUid,
    String clientId,
    String clientName,
  })>[];
  bool fail = false;

  @override
  Future<void> send({
    required String vendorUid,
    required String buyerUid,
    required String clientId,
    required String clientName,
  }) async {
    if (fail) {
      throw const BuyerException('Sin señal. Inténtalo en un momento.');
    }
    sent.add((
      vendorUid: vendorUid,
      buyerUid: buyerUid,
      clientId: clientId,
      clientName: clientName,
    ));
  }

  @override
  Stream<List<PanRequest>> watch(String vendorUid) =>
      Stream<List<PanRequest>>.value(const []);

  @override
  Future<void> markSeen({
    required String vendorUid,
    required String buyerUid,
  }) async {}
}

class _FakeBuyerRemote implements BuyerRemoteDataSource {
  final invites = <String, InviteLookup>{};
  final clients = <String, Client>{};
  final movements = <String, List<Movement>>{};
  final links = <String, LinkedAccount>{};
  final vendorNames = <String, String>{};
  final claimed = <String>[];
  final linkedClients = <String>[];
  bool linksFail = false;

  static String key(String vendorUid, String clientId) =>
      '$vendorUid/$clientId';

  @override
  Future<InviteLookup?> fetchInvite(String code) async => invites[code];

  @override
  Future<void> claimInvite({
    required String code,
    required String buyerUid,
  }) async {
    claimed.add(code);
  }

  @override
  Future<void> linkClient({
    required String vendorUid,
    required String clientId,
    required String buyerUid,
  }) async {
    linkedClients.add(key(vendorUid, clientId));
  }

  @override
  Future<Client?> fetchClient({
    required String vendorUid,
    required String clientId,
  }) async => clients[key(vendorUid, clientId)];

  @override
  Future<List<Movement>> fetchMovements({
    required String vendorUid,
    required String clientId,
  }) async => movements[key(vendorUid, clientId)] ?? const [];

  @override
  Future<String> fetchVendorName(String vendorUid) async {
    return vendorNames[vendorUid] ?? '';
  }

  @override
  Future<List<LinkedAccount>> fetchLinks(String buyerUid) async {
    if (linksFail) {
      throw const BuyerException('Sin señal. Inténtalo en un momento.');
    }
    return links.values.toList(growable: false);
  }

  @override
  Future<void> saveLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {
    if (linksFail) {
      throw const BuyerException('Sin señal. Inténtalo en un momento.');
    }
    links[account.id] = account;
  }

  @override
  Future<void> removeLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {
    links.remove(account.id);
  }

  @override
  Future<void> ensureVendorMarker({
    required String buyerUid,
    required LinkedAccount account,
  }) async {}
}

Client _client({
  required String vendorUid,
  required String id,
  required String name,
  bool active = true,
}) {
  return Client(
    id: id,
    vendorUid: vendorUid,
    name: name,
    phone: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    pendingSync: false,
    active: active,
    inviteCode: 'ABC23X',
    linkedUid: 'buyer1',
  );
}

Movement _fiado({
  required String vendorUid,
  required String clientId,
  required int amount,
}) {
  return Movement(
    id: 'mov-$vendorUid-$clientId',
    vendorUid: vendorUid,
    clientId: clientId,
    kind: MovementKind.fiado,
    amountCents: amount,
    occurredAt: DateTime(2026, 8, 1),
    createdAt: DateTime(2026, 8, 1),
    pendingSync: false,
  );
}

/// Dos vendedores distintos anotaron al mismo comprador.
_FakeBuyerRemote _twoVendors() {
  final remote = _FakeBuyerRemote();
  remote.invites['ABC23X'] = const InviteLookup(
    vendorUid: 'vendor1',
    clientId: 'client-aa',
    active: true,
    linkedUid: '',
    vendorName: 'Ana',
  );
  remote.invites['XYZ99K'] = const InviteLookup(
    vendorUid: 'vendor2',
    clientId: 'client-bb',
    active: true,
    linkedUid: '',
    vendorName: 'Luis',
  );
  remote.clients['vendor1/client-aa'] = _client(
    vendorUid: 'vendor1',
    id: 'client-aa',
    name: 'Ander',
  );
  remote.clients['vendor2/client-bb'] = _client(
    vendorUid: 'vendor2',
    id: 'client-bb',
    name: 'Ander',
  );
  remote.movements['vendor1/client-aa'] = [
    _fiado(vendorUid: 'vendor1', clientId: 'client-aa', amount: 5000),
  ];
  remote.movements['vendor2/client-bb'] = [
    _fiado(vendorUid: 'vendor2', clientId: 'client-bb', amount: 2000),
  ];
  remote.vendorNames['vendor1'] = 'Ana';
  remote.vendorNames['vendor2'] = 'Luis';
  return remote;
}

Future<BuyerViewModel> _build(
  _FakeBuyerRemote remote, {
  LinkedAccountStore? store,
  _FakeInbox? inbox,
}) async {
  final viewModel = BuyerViewModel(
    observeAuthState: ObserveAuthState(_Auth()),
    store: store ?? LinkedAccountStore.memory(),
    remote: remote,
    inbox: inbox ?? _FakeInbox(),
  );
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return viewModel;
}

void main() {
  test('vincula con el código y muestra el saldo', () async {
    final remote = _twoVendors();
    final viewModel = await _build(remote);

    final ok = await viewModel.linkWithCode('abc23x');

    expect(ok, isTrue);
    expect(remote.claimed, ['ABC23X']);
    expect(remote.linkedClients, ['vendor1/client-aa']);
    expect(viewModel.ledgers.single.client.name, 'Ander');
    expect(viewModel.ledgers.single.vendorLabel, 'Ana');
    expect(viewModel.totalbalanceCents, 5000);

    viewModel.dispose();
  });

  test('ve las deudas de dos vendedores sin que se pisen', () async {
    final remote = _twoVendors();
    final viewModel = await _build(remote);

    expect(await viewModel.linkWithCode('ABC23X'), isTrue);
    expect(await viewModel.linkWithCode('XYZ99K'), isTrue);

    expect(viewModel.ledgers.length, 2);
    expect(viewModel.totalbalanceCents, 7000);

    final ana = viewModel.ledgers.firstWhere((l) => l.vendorLabel == 'Ana');
    final luis = viewModel.ledgers.firstWhere((l) => l.vendorLabel == 'Luis');
    expect(ana.balanceCents, 5000);
    expect(luis.balanceCents, 2000);
    expect(remote.links.length, 2);

    viewModel.dispose();
  });

  test('no se vincula dos veces con el mismo vendedor', () async {
    final remote = _twoVendors();
    final viewModel = await _build(remote);

    expect(await viewModel.linkWithCode('ABC23X'), isTrue);
    expect(await viewModel.linkWithCode('ABC23X'), isFalse);

    expect(viewModel.ledgers.length, 1);
    expect(viewModel.errorMessage, contains('Ya estabas vinculado'));

    viewModel.dispose();
  });

  test('sin señal para la libreta usa lo recordado en el teléfono', () async {
    final remote = _twoVendors();
    final store = LinkedAccountStore.memory();
    await store.save(
      buyerUid: 'buyer1',
      accounts: const [
        LinkedAccount(
          vendorUid: 'vendor1',
          clientId: 'client-aa',
          vendorName: 'Ana',
        ),
      ],
    );
    remote.linksFail = true;

    final viewModel = await _build(remote, store: store);

    expect(viewModel.ledgers.single.vendorLabel, 'Ana');
    expect(viewModel.totalbalanceCents, 5000);

    viewModel.dispose();
  });

  test('olvida el vínculo si el vendedor desactivó la ficha', () async {
    final remote = _twoVendors();
    final viewModel = await _build(remote);
    expect(await viewModel.linkWithCode('ABC23X'), isTrue);

    remote.clients['vendor1/client-aa'] = _client(
      vendorUid: 'vendor1',
      id: 'client-aa',
      name: 'Ander',
      active: false,
    );
    await viewModel.refresh();

    expect(viewModel.ledgers, isEmpty);
    expect(remote.links, isEmpty);
    expect(viewModel.errorMessage, contains('ya no está activa'));

    viewModel.dispose();
  });

  test('muestra el nombre que publicó el vendedor, no uno viejo', () async {
    final remote = _twoVendors();
    final store = LinkedAccountStore.memory();
    // Marcador guardado antes de que el vendedor publicara su nombre.
    await store.save(
      buyerUid: 'buyer1',
      accounts: const [
        LinkedAccount(vendorUid: 'vendor1', clientId: 'client-aa'),
      ],
    );

    final viewModel = await _build(remote, store: store);

    expect(viewModel.ledgers.single.vendorLabel, 'Ana');
    expect(remote.links['vendor1_client-aa']?.vendorName, 'Ana');

    viewModel.dispose();
  });

  test('si el vendedor no publicó nombre, dice Tu vendedor', () async {
    final remote = _twoVendors()..vendorNames.clear();
    remote.invites['ABC23X'] = const InviteLookup(
      vendorUid: 'vendor1',
      clientId: 'client-aa',
      active: true,
      linkedUid: '',
    );
    final viewModel = await _build(remote);

    expect(await viewModel.linkWithCode('ABC23X'), isTrue);
    expect(viewModel.ledgers.single.vendorLabel, 'Tu vendedor');

    viewModel.dispose();
  });

  test('rechaza un código inválido sin llamar a la nube', () async {
    final remote = _FakeBuyerRemote();
    final viewModel = await _build(remote);

    final ok = await viewModel.linkWithCode('hola');

    expect(ok, isFalse);
    expect(viewModel.errorMessage, contains('6 letras'));
    expect(remote.claimed, isEmpty);

    viewModel.dispose();
  });

  test('pide pan al vendedor vinculado', () async {
    final remote = _twoVendors();
    final inbox = _FakeInbox();
    final viewModel = await _build(remote, inbox: inbox);
    await viewModel.linkWithCode('ABC23X');

    final ok = await viewModel.requestPan(viewModel.ledgers.single);

    expect(ok, isTrue);
    expect(inbox.sent, hasLength(1));
    expect(inbox.sent.single.vendorUid, 'vendor1');
    expect(inbox.sent.single.buyerUid, 'buyer1');
    expect(inbox.sent.single.clientId, 'client-aa');
    expect(inbox.sent.single.clientName, 'Ander');
    expect(viewModel.panStatus, contains('Ana'));
    expect(viewModel.sendingPan(viewModel.ledgers.single.account.id), isFalse);

    viewModel.dispose();
  });

  test('si no hay señal, no finge el envío del recado', () async {
    final remote = _twoVendors();
    final inbox = _FakeInbox()..fail = true;
    final viewModel = await _build(remote, inbox: inbox);
    await viewModel.linkWithCode('ABC23X');

    final ok = await viewModel.requestPan(viewModel.ledgers.single);

    expect(ok, isFalse);
    expect(inbox.sent, isEmpty);
    expect(viewModel.panStatus, isNull);
    expect(viewModel.errorMessage, contains('señal'));

    viewModel.dispose();
  });
}
