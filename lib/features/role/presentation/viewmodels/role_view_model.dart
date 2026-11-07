import 'dart:async';

import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/usecases/load_account.dart';
import 'package:flutter/foundation.dart';

enum RoleStatus { unknown, none, ready, failed }

/// El rol lo decide la nube. Aquí solo se lee y se recuerda para arrancar
/// sin señal; el caché no da permisos, las reglas de Firestore mandan.
class RoleViewModel extends ChangeNotifier {
  RoleViewModel({
    required ObserveAuthState observeAuthState,
    required this.loadAccount,
  }) {
    _authSubscription = observeAuthState().listen(_onAuthState);
  }

  final LoadAccount loadAccount;

  late final StreamSubscription<UserSession?> _authSubscription;

  RoleStatus _status = RoleStatus.unknown;
  UserRole? _role;
  AccountProfile? _account;
  UserSession? _session;
  String? _uid;
  String? _errorMessage;
  bool _fromCache = false;

  RoleStatus get status => _status;
  UserRole? get role => _role;
  AccountProfile? get account => _account;
  String? get uid => _uid;
  String? get errorMessage => _errorMessage;

  /// Rol tomado del teléfono porque la nube no respondió.
  bool get isFromCache => _fromCache;

  bool get canSell => _role?.canSell ?? false;
  bool get isAdmin => _role?.canManageAccounts ?? false;

  Future<void> _onAuthState(UserSession? session) async {
    _session = session;
    final uid = InputSanitizer.uid(session?.uid);
    _uid = uid;
    _errorMessage = null;
    _fromCache = false;

    if (session == null || uid == null) {
      _role = null;
      _account = null;
      _status = RoleStatus.none;
      notifyListeners();
      return;
    }

    _status = RoleStatus.unknown;
    _role = null;
    _account = null;
    notifyListeners();

    await _load(session);
  }

  /// Reintento manual desde la pantalla de error.
  Future<void> retry() async {
    final session = _session;
    if (session == null) return;
    _status = RoleStatus.unknown;
    _errorMessage = null;
    notifyListeners();
    await _load(session);
  }

  Future<void> _load(UserSession session) async {
    final uid = InputSanitizer.uid(session.uid);
    if (uid == null) return;

    try {
      final account = await loadAccount(session);
      _account = account;
      _role = account.role;
      _fromCache = false;
      _status = RoleStatus.ready;
      _errorMessage = null;
    } catch (error, stack) {
      debugPrint('Account load failed: ${error.runtimeType}');
      debugPrint('$stack');
      final cached = await _cachedRole(uid);
      if (cached != null) {
        _role = cached;
        _fromCache = true;
        _status = RoleStatus.ready;
        _errorMessage = null;
      } else {
        _role = null;
        _status = RoleStatus.failed;
        _errorMessage = error is RoleException
            ? error.userMessage
            : 'No se pudo confirmar tu cuenta. Revisa la señal.';
      }
    }
    notifyListeners();
  }

  Future<UserRole?> _cachedRole(String uid) async {
    try {
      return await loadAccount.cached(uid);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
