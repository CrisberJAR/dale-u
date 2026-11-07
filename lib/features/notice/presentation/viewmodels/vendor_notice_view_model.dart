import 'dart:async';

import 'package:dale_u/core/error/notice_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/notice/data/notice_remote.dart';
import 'package:flutter/foundation.dart';

class VendorNoticeViewModel extends ChangeNotifier {
  VendorNoticeViewModel({
    required ObserveAuthState observeAuthState,
    required NoticeRemote this.remote,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  VendorNoticeViewModel.idle() : remote = null;

  final NoticeRemote? remote;
  StreamSubscription<UserSession?>? _authSubscription;

  String? _vendorUid;
  bool _saving = false;
  String? _errorMessage;
  String? _status;

  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  String? get status => _status;

  void _onAuth(UserSession? session) {
    _vendorUid = InputSanitizer.uid(session?.uid);
    _errorMessage = null;
    _status = null;
    notifyListeners();
  }

  Future<bool> send({
    required String body,
    required String vendorName,
    required List<String> buyerUids,
  }) async {
    final uid = _vendorUid;
    final cloud = remote;
    if (uid == null || cloud == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    final text = InputSanitizer.notice(body);
    if (text == null) {
      _errorMessage = 'Escribe el aviso, por ejemplo: hoy no hay pan.';
      notifyListeners();
      return false;
    }
    final buyers = <String>{};
    for (final raw in buyerUids) {
      final id = InputSanitizer.uid(raw);
      if (id != null) buyers.add(id);
    }
    if (buyers.isEmpty) {
      _errorMessage = 'Nadie tiene la app vinculada todavía.';
      notifyListeners();
      return false;
    }
    if (_saving) return false;
    _saving = true;
    _errorMessage = null;
    _status = null;
    notifyListeners();
    try {
      await cloud.sendToBuyers(
        vendorUid: uid,
        vendorName: vendorName,
        body: text,
        buyerUids: buyers.toList(),
      );
      final n = buyers.length;
      _status = n == 1
          ? 'Aviso enviado a 1 cliente.'
          : 'Aviso enviado a $n clientes.';
      return true;
    } on NoticeException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Notice send failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo enviar el aviso. Inténtalo de nuevo.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
