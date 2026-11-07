import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/notice_exception.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/notice/data/notice_remote.dart';
import 'package:dale_u/features/notice/domain/vendor_notice.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/vendor_notice_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthRepository {
  @override
  Stream<UserSession?> observeAuthState() {
    return Stream.value(
      const UserSession(uid: 'vendor1', email: 'a@b.com', displayName: 'Ana'),
    );
  }

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

class _FakeNotice implements NoticeRemote {
  final sent = <({String vendorUid, String body, List<String> buyers})>[];
  bool fail = false;

  @override
  Future<void> sendToBuyers({
    required String vendorUid,
    required String vendorName,
    required String body,
    required List<String> buyerUids,
  }) async {
    if (fail) {
      throw const NoticeException('Sin señal. Inténtalo en un momento.');
    }
    sent.add((vendorUid: vendorUid, body: body, buyers: buyerUids));
  }

  @override
  Stream<List<VendorNotice>> watchBuyer(String buyerUid) =>
      Stream.value(const []);

  @override
  Future<void> markSeen({
    required String buyerUid,
    required String vendorUid,
  }) async {}
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('envía el aviso a los compradores vinculados', () async {
    final remote = _FakeNotice();
    final viewModel = VendorNoticeViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth()),
      remote: remote,
    );
    await _pump();

    final ok = await viewModel.send(
      body: 'Hoy no hay pan',
      vendorName: 'Ana',
      buyerUids: const ['buyer1', 'buyer2', 'buyer1'],
    );

    expect(ok, isTrue);
    expect(viewModel.status, 'Aviso enviado a 2 clientes.');
    expect(remote.sent.single.buyers, unorderedEquals(['buyer1', 'buyer2']));
    viewModel.dispose();
  });

  test('sin clientes con app no llama a la nube', () async {
    final remote = _FakeNotice();
    final viewModel = VendorNoticeViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth()),
      remote: remote,
    );
    await _pump();

    final ok = await viewModel.send(
      body: 'Hoy no hay pan',
      vendorName: 'Ana',
      buyerUids: const [],
    );

    expect(ok, isFalse);
    expect(viewModel.errorMessage, 'Nadie tiene la app vinculada todavía.');
    expect(remote.sent, isEmpty);
    viewModel.dispose();
  });
}
