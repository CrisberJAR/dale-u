import 'dart:async';

import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/notice/data/notice_remote.dart';
import 'package:dale_u/features/notice/domain/vendor_notice.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/buyer_notice_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthRepository {
  @override
  Stream<UserSession?> observeAuthState() {
    return Stream.value(
      const UserSession(uid: 'buyer1', email: 'a@b.com', displayName: 'Ander'),
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
  final controller = StreamController<List<VendorNotice>>.broadcast();
  final seen = <String>[];

  @override
  Future<void> sendToBuyers({
    required String vendorUid,
    required String vendorName,
    required String body,
    required List<String> buyerUids,
  }) async {}

  @override
  Stream<List<VendorNotice>> watchBuyer(String buyerUid) => controller.stream;

  @override
  Future<void> markSeen({
    required String buyerUid,
    required String vendorUid,
  }) async {
    seen.add('$buyerUid/$vendorUid');
  }
}

VendorNotice _notice() {
  return VendorNotice(
    vendorUid: 'vendor1',
    vendorName: 'Ana',
    body: 'Hoy no hay pan',
    createdAt: DateTime(2026, 9, 2, 8),
  );
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('muestra el aviso y Entendido lo quita', () async {
    final remote = _FakeNotice();
    final viewModel = BuyerNoticeViewModel(
      observeAuthState: ObserveAuthState(_FakeAuth()),
      remote: remote,
    );
    await _pump();

    remote.controller.add([_notice()]);
    await _pump();
    expect(viewModel.notices.single.body, 'Hoy no hay pan');
    expect(viewModel.notices.single.headline, 'Ana avisa');

    await viewModel.markSeen(viewModel.notices.single);
    expect(viewModel.notices, isEmpty);
    expect(remote.seen, ['buyer1/vendor1']);

    await remote.controller.close();
    viewModel.dispose();
  });
}
