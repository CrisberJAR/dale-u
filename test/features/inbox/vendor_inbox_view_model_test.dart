import 'dart:async';

import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.session);

  final UserSession? session;

  @override
  Stream<UserSession?> observeAuthState() => Stream.value(session);

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

class _FakeInbox implements PanInboxRemote {
  final controller = StreamController<List<PanRequest>>.broadcast();
  final seen = <String>[];

  @override
  Future<void> send({
    required String vendorUid,
    required String buyerUid,
    required String clientId,
    required String clientName,
  }) async {}

  @override
  Stream<List<PanRequest>> watch(String vendorUid) => controller.stream;

  @override
  Future<void> markSeen({
    required String vendorUid,
    required String buyerUid,
  }) async {
    seen.add('$vendorUid/$buyerUid');
  }
}

const _session = UserSession(
  uid: 'vendor1',
  email: 'ana@pan.com',
  displayName: 'Ana',
);

PanRequest _req({
  String buyer = 'buyer1',
  String client = 'client-aa',
  String name = 'Ander',
  DateTime? at,
}) {
  return PanRequest(
    buyerUid: buyer,
    clientId: client,
    clientName: name,
    createdAt: at ?? DateTime(2026, 8, 30, 10),
  );
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('al abrir la ruta lee recados y anuncia el primero', () async {
    final inbox = _FakeInbox();
    final viewModel = VendorInboxViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth(_session)),
      remote: inbox,
    );
    await _pump();

    inbox.controller.add([_req()]);
    await _pump();

    expect(viewModel.unread.single.clientName, 'Ander');
    expect(viewModel.freshSpoken, 'Ander te pidió pan.');

    viewModel.clearSpoken();
    inbox.controller.add([_req()]);
    await _pump();
    expect(viewModel.freshSpoken, isNull);

    await inbox.controller.close();
    viewModel.dispose();
  });

  test('si el mismo comprador vuelve a pedir, lo anuncia otra vez', () async {
    final inbox = _FakeInbox();
    final viewModel = VendorInboxViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth(_session)),
      remote: inbox,
    );
    await _pump();

    inbox.controller.add([_req()]);
    await _pump();
    viewModel.clearSpoken();

    inbox.controller.add([_req(at: DateTime(2026, 8, 30, 11))]);
    await _pump();
    expect(viewModel.freshSpoken, 'Ander te pidió pan.');

    await inbox.controller.close();
    viewModel.dispose();
  });

  test('marcar visto lo quita de la lista sin volver a anunciarlo', () async {
    final inbox = _FakeInbox();
    final viewModel = VendorInboxViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth(_session)),
      remote: inbox,
    );
    await _pump();

    final request = _req();
    inbox.controller.add([request]);
    await _pump();
    viewModel.clearSpoken();

    await viewModel.markSeen(request);
    expect(viewModel.unread, isEmpty);
    expect(inbox.seen, ['vendor1/buyer1']);

    inbox.controller.add([request]);
    await _pump();
    expect(viewModel.unread, hasLength(1));
    expect(viewModel.freshSpoken, isNull);

    await inbox.controller.close();
    viewModel.dispose();
  });
}
