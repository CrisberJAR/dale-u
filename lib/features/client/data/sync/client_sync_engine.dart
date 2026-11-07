import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/client/domain/usecases/sync_clients.dart';
import 'package:dale_u/features/ledger/domain/usecases/sync_movements.dart';
import 'package:flutter/foundation.dart';

/// Sincroniza en segundo plano al iniciar sesión y al recuperar red.
class ClientSyncEngine {
  ClientSyncEngine({
    required ObserveAuthState observeAuthState,
    required this.syncClients,
    required this.syncMovements,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity() {
    _authSubscription = observeAuthState().listen(_onAuth);
    _netSubscription = _connectivity.onConnectivityChanged.listen(_onNetwork);
    unawaited(_connectivity.checkConnectivity().then(_onNetwork));
  }

  final SyncClients syncClients;
  final SyncMovements syncMovements;
  final Connectivity _connectivity;

  late final StreamSubscription<UserSession?> _authSubscription;
  late final StreamSubscription<List<ConnectivityResult>> _netSubscription;

  String? _vendorUid;

  void _onAuth(UserSession? session) {
    _vendorUid = InputSanitizer.uid(session?.uid);
    unawaited(flush());
  }

  void _onNetwork(List<ConnectivityResult> results) {
    if (_isOnline(results)) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    final uid = _vendorUid;
    if (uid == null) return;
    try {
      await syncClients(uid);
      await syncMovements(uid);
    } catch (error, stack) {
      debugPrint('Background sync failed: ${error.runtimeType}');
      debugPrint('$stack');
    }
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _netSubscription.cancel();
  }
}
