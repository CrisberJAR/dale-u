import 'dart:async';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/notice/data/notice_remote.dart';
import 'package:dale_u/features/notice/domain/vendor_notice.dart';
import 'package:flutter/foundation.dart';

class BuyerNoticeViewModel extends ChangeNotifier {
  BuyerNoticeViewModel({
    required ObserveAuthState observeAuthState,
    required NoticeRemote this.remote,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  BuyerNoticeViewModel.idle() : remote = null;

  final NoticeRemote? remote;
  StreamSubscription<UserSession?>? _authSubscription;
  StreamSubscription<List<VendorNotice>>? _watchSub;

  String? _buyerUid;
  List<VendorNotice> _notices = const [];

  List<VendorNotice> get notices => _notices;

  void _onAuth(UserSession? session) {
    _buyerUid = InputSanitizer.uid(session?.uid);
    unawaited(_watchSub?.cancel());
    _watchSub = null;
    _notices = const [];
    notifyListeners();
    final uid = _buyerUid;
    final cloud = remote;
    if (uid == null || cloud == null) return;
    _watchSub = cloud.watchBuyer(uid).listen(
      (items) {
        _notices = items;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Notice watch failed: ${error.runtimeType}');
        debugPrint('$stack');
      },
    );
  }

  Future<void> markSeen(VendorNotice notice) async {
    final uid = _buyerUid;
    final cloud = remote;
    if (uid == null || cloud == null) return;
    _notices = _notices
        .where((item) => item.vendorUid != notice.vendorUid)
        .toList();
    notifyListeners();
    await cloud.markSeen(buyerUid: uid, vendorUid: notice.vendorUid);
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_watchSub?.cancel());
    super.dispose();
  }
}
