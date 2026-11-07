import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/client/domain/usecases/sync_clients.dart';
import 'package:dale_u/features/ledger/domain/usecases/sync_movements.dart';
import 'package:flutter/foundation.dart';

/// Sincroniza en segundo plano al iniciar sesión, al recuperar red y, si
/// falla, reintenta solo con espera creciente (30 s, 1, 2, 4… hasta 5 min).
///
/// Mientras el vendedor está en ruta el servicio de ubicación mantiene la
/// app viva, así que estos reintentos siguen con la pantalla apagada.
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

  static const firstRetry = Duration(seconds: 30);
  static const maxRetry = Duration(minutes: 5);

  final SyncClients syncClients;
  final SyncMovements syncMovements;
  final Connectivity _connectivity;

  late final StreamSubscription<UserSession?> _authSubscription;
  late final StreamSubscription<List<ConnectivityResult>> _netSubscription;

  String? _vendorUid;
  bool _online = true;
  Timer? _retry;
  Duration _nextRetry = firstRetry;

  void _onAuth(UserSession? session) {
    _vendorUid = InputSanitizer.uid(session?.uid);
    _cancelRetry();
    unawaited(flush());
  }

  void _onNetwork(List<ConnectivityResult> results) {
    _online = _isOnline(results);
    if (_online) {
      _cancelRetry();
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    final uid = _vendorUid;
    if (uid == null) return;
    try {
      await syncClients(uid);
      await syncMovements(uid);
      _nextRetry = firstRetry;
    } catch (error, stack) {
      debugPrint('Background sync failed: ${error.runtimeType}');
      debugPrint('$stack');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (!_online || _retry != null) return;
    final wait = _nextRetry;
    final doubled = _nextRetry * 2;
    _nextRetry = doubled > maxRetry ? maxRetry : doubled;
    _retry = Timer(wait, () {
      _retry = null;
      unawaited(flush());
    });
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
    _nextRetry = firstRetry;
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    _cancelRetry();
    await _authSubscription.cancel();
    await _netSubscription.cancel();
  }
}
