import 'dart:async';

import 'package:dale_u/core/error/presence_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/data/presence_local_store.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:dale_u/features/presence/domain/presence_policy.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:flutter/foundation.dart';

/// Publica un punto cada 5 minutos si el vendedor se movió. Offline: el
/// interruptor queda en el teléfono; la nube se actualiza cuando hay señal.
class PresenceViewModel extends ChangeNotifier {
  PresenceViewModel({
    required ObserveAuthState observeAuthState,
    required this.location,
    required this.remote,
    required this.store,
    this.now,
  }) {
    _onRoute = store.onRoute;
    _lastAt = store.lastAt;
    final lat = store.lastLatitude;
    final lng = store.lastLongitude;
    if (lat != null && lng != null) {
      _lastFix = GeoFix(latitude: lat, longitude: lng);
      _lastReadFix = _lastFix;
    }
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  final LocationGateway location;
  final PresenceRemoteDataSource remote;
  final PresenceLocalStore store;
  final DateTime Function()? now;

  late final StreamSubscription<UserSession?> _authSubscription;
  Timer? _timer;
  String? _vendorUid;
  bool _onRoute = false;
  bool _busy = false;
  bool _locating = false;
  String? _errorMessage;
  GeoFix? _lastFix;
  DateTime? _lastAt;
  GeoFix? _lastReadFix;

  bool get onRoute => _onRoute;
  bool get busy => _busy;
  bool get locating => _locating;
  String? get errorMessage => _errorMessage;
  DateTime? get lastPublishedAt => _lastAt;

  /// Última lectura local. Sirve al radar; no tiene que estar en la nube.
  GeoFix? get lastReadFix => _lastReadFix;

  void _onAuth(UserSession? session) {
    _vendorUid = InputSanitizer.uid(session?.uid);
    if (_vendorUid == null) {
      unawaited(_stopLocalOnly());
      return;
    }
    if (_onRoute) {
      _startTicker();
    }
  }

  Future<void> toggle() async {
    if (_busy) return;
    if (_onRoute) {
      await leaveRoute();
    } else {
      await enterRoute();
    }
  }

  Future<void> enterRoute() async {
    final uid = _vendorUid;
    if (uid == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return;
    }
    _busy = true;
    _errorMessage = null;
    notifyListeners();

    final blocked = await location.ensureReady();
    if (blocked != null) {
      _busy = false;
      _errorMessage = blocked;
      notifyListeners();
      return;
    }

    _onRoute = true;
    await store.setOnRoute(true);
    _busy = false;
    notifyListeners();
    await _publishTick(force: true);
    _startTicker();
  }

  Future<void> leaveRoute() async {
    _timer?.cancel();
    _timer = null;
    _onRoute = false;
    await store.setOnRoute(false);
    await store.clearFix();
    _lastFix = null;
    _lastReadFix = null;
    _errorMessage = null;
    notifyListeners();

    final uid = _vendorUid;
    if (uid == null) return;
    try {
      await remote.publish(
        uid,
        VendorPresence(onRoute: false, updatedAt: _now()),
      );
    } on PresenceException catch (error) {
      _errorMessage = error.userMessage;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Leave route failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo avisar que saliste de la ruta.';
      notifyListeners();
    }
  }

  Future<void> retryPublish() => _publishTick(force: true);

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(PresencePolicy.localPoll, (_) {
      unawaited(_publishTick());
    });
  }

  Future<void> _publishTick({bool force = false}) async {
    if (!_onRoute) return;
    final uid = _vendorUid;
    if (uid == null) return;

    final showLocating = force || _lastAt == null;
    if (showLocating) {
      _locating = true;
      notifyListeners();
    }
    try {
      final fix = await location.readFix();
      if (fix == null) {
        _errorMessage = 'No pude leer el GPS. Inténtalo de nuevo.';
        notifyListeners();
        return;
      }
      _lastReadFix = fix;
      final stamp = _now();
      if (!force &&
          !PresencePolicy.shouldPublish(
            lastFix: _lastFix,
            lastAt: _lastAt,
            next: fix,
            now: stamp,
          )) {
        notifyListeners();
        return;
      }
      await remote.publish(
        uid,
        VendorPresence(onRoute: true, updatedAt: stamp, fix: fix),
      );
      _lastFix = fix;
      _lastAt = stamp;
      _errorMessage = null;
      await store.rememberFix(
        latitude: fix.latitude,
        longitude: fix.longitude,
        at: stamp,
      );
      notifyListeners();
    } on PresenceException catch (error) {
      _errorMessage = error.userMessage;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Publish presence failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'Sin señal. Se intentará de nuevo en cinco minutos.';
      notifyListeners();
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  Future<void> _stopLocalOnly() async {
    _timer?.cancel();
    _timer = null;
    _onRoute = false;
    await store.setOnRoute(false);
    notifyListeners();
  }

  DateTime _now() => now?.call() ?? DateTime.now();

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
