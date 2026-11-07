import 'dart:async';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:flutter/foundation.dart';

/// Recados del comprador. Solo mientras la app del vendedor está abierta.
class VendorInboxViewModel extends ChangeNotifier {
  VendorInboxViewModel({
    required ObserveAuthState observeAuthState,
    required this.remote,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  final PanInboxRemote remote;
  late final StreamSubscription<UserSession?> _authSubscription;
  StreamSubscription<List<PanRequest>>? _inboxSub;

  String? _vendorUid;
  List<PanRequest> _unread = const [];
  String? _freshSpoken;
  final _heardAt = <String, DateTime>{};

  List<PanRequest> get unread => _unread;
  String? get freshSpoken => _freshSpoken;

  void clearSpoken() {
    _freshSpoken = null;
  }

  void _onAuth(UserSession? session) {
    _vendorUid = InputSanitizer.uid(session?.uid);
    unawaited(_inboxSub?.cancel());
    _inboxSub = null;
    _unread = const [];
    _heardAt.clear();
    _freshSpoken = null;
    notifyListeners();
    final uid = _vendorUid;
    if (uid == null) return;
    _inboxSub = remote.watch(uid).listen(
      _onSnapshot,
      onError: (Object error, StackTrace stack) {
        debugPrint('Inbox watch failed: ${error.runtimeType}');
        debugPrint('$stack');
      },
    );
  }

  void _onSnapshot(List<PanRequest> requests) {
    final newcomers = requests.where((item) {
      final heard = _heardAt[item.buyerUid];
      return heard == null || item.createdAt.isAfter(heard);
    }).toList();
    if (newcomers.isNotEmpty) {
      _freshSpoken = newcomers.first.label;
    }
    _heardAt.clear();
    for (final item in requests) {
      _heardAt[item.buyerUid] = item.createdAt;
    }
    _unread = requests;
    notifyListeners();
  }

  Future<void> markSeen(PanRequest request) async {
    final uid = _vendorUid;
    if (uid == null) return;
    _unread = _unread
        .where((item) => item.buyerUid != request.buyerUid)
        .toList();
    notifyListeners();
    await remote.markSeen(vendorUid: uid, buyerUid: request.buyerUid);
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    unawaited(_inboxSub?.cancel());
    super.dispose();
  }
}
