import 'dart:async';

import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_out.dart';
import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, unauthenticated, loading, authenticated }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required ObserveAuthState observeAuthState,
    required this.signInWithGoogle,
    required this.signOutUseCase,
  }) {
    _subscription = observeAuthState().listen(_onAuthState);
  }

  final SignInWithGoogle signInWithGoogle;
  final SignOut signOutUseCase;
  late final StreamSubscription<UserSession?> _subscription;

  AuthStatus _status = AuthStatus.unknown;
  UserSession? _session;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserSession? get session => _session;
  String? get errorMessage => _errorMessage;

  void _onAuthState(UserSession? session) {
    _session = session;
    _status = session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
    if (session != null) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    if (_status == AuthStatus.loading) return;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await signInWithGoogle();
    switch (result) {
      case Ok():
        break;
      case Err(:final failure):
        if (failure.isCancelled) {
          _status = AuthStatus.unauthenticated;
          _errorMessage = null;
        } else {
          _status = AuthStatus.unauthenticated;
          _errorMessage = failure.userMessage;
        }
        notifyListeners();
    }
  }

  Future<void> signOut() async {
    final previous = _status;
    _status = AuthStatus.loading;
    notifyListeners();
    final result = await signOutUseCase();
    switch (result) {
      case Ok():
        break;
      case Err(:final failure):
        _status = previous;
        _errorMessage = failure.userMessage;
        notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
