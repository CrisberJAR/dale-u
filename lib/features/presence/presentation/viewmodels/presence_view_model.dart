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

/// Sigue el GPS mientras el vendedor está en ruta (también con la pantalla
/// apagada) y sube un punto cuando avanza. Offline: el interruptor queda en
/// el teléfono; la nube se actualiza cuando vuelve la señal.
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

  /// Revisa el latido aunque el GPS no mande nada (vendedor quieto).
  static const heartbeatCheck = Duration(minutes: 1);

  final LocationGateway location;
  final PresenceRemoteDataSource remote;
  final PresenceLocalStore store;
  final DateTime Function()? now;

  late final StreamSubscription<UserSession?> _authSubscription;
  StreamSubscription<GeoFix>? _gpsSubscription;
  Timer? _heartbeat;
  String? _vendorUid;
  bool _onRoute = false;
  bool _busy = false;
  bool _locating = false;
  bool _publishing = false;
  bool _disposed = false;
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
      _startTracking();
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
      _notify();
      return;
    }
    _busy = true;
    _errorMessage = null;
    _notify();

    final blocked = await location.ensureReady();
    if (blocked != null) {
      _busy = false;
      _errorMessage = blocked;
      _notify();
      return;
    }

    _onRoute = true;
    await store.setOnRoute(true);
    _busy = false;
    _notify();
    await _readAndPublish(force: true);
    _startTracking();
  }

  Future<void> leaveRoute() async {
    await _stopTracking();
    _onRoute = false;
    await store.setOnRoute(false);
    await store.clearFix();
    _lastFix = null;
    _lastAt = null;
    _lastReadFix = null;
    _errorMessage = null;
    _notify();

    final uid = _vendorUid;
    if (uid == null) return;
    try {
      await remote.publish(
        uid,
        VendorPresence(onRoute: false, updatedAt: _now()),
      );
    } on PresenceException catch (error) {
      _errorMessage = error.userMessage;
      _notify();
    } catch (error, stack) {
      debugPrint('Leave route failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo avisar que saliste de la ruta.';
      _notify();
    }
  }

  Future<void> retryPublish() => _readAndPublish(force: true);

  void _startTracking() {
    unawaited(_gpsSubscription?.cancel());
    _gpsSubscription = location.watch().listen(
      (fix) => unawaited(_onFix(fix)),
      onError: (Object error, StackTrace stack) {
        debugPrint('GPS stream failed: ${error.runtimeType}');
        _errorMessage = 'El GPS se detuvo. Pulsa Reintentar ubicación.';
        _notify();
      },
    );
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatCheck, (_) {
      final fix = _lastReadFix;
      if (fix != null) unawaited(_publish(fix));
    });
  }

  Future<void> _stopTracking() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  Future<void> _onFix(GeoFix fix) async {
    if (!_onRoute) return;
    _lastReadFix = fix;
    _notify();
    await _publish(fix);
  }

  Future<void> _readAndPublish({required bool force}) async {
    if (!_onRoute) return;
    _locating = true;
    _notify();
    try {
      final fix = await location.readFix();
      if (fix == null) {
        _errorMessage = 'No pude leer el GPS. Inténtalo de nuevo.';
        return;
      }
      _lastReadFix = fix;
      await _publish(fix, force: force);
    } catch (error, stack) {
      debugPrint('Read GPS failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No pude leer el GPS. Inténtalo de nuevo.';
    } finally {
      _locating = false;
      _notify();
    }
  }

  Future<void> _publish(GeoFix fix, {bool force = false}) async {
    if (!_onRoute || _publishing) return;
    final uid = _vendorUid;
    if (uid == null) return;
    final stamp = _now();
    if (!force &&
        !PresencePolicy.shouldPublish(
          lastFix: _lastFix,
          lastAt: _lastAt,
          next: fix,
          now: stamp,
        )) {
      return;
    }
    _publishing = true;
    try {
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
    } on PresenceException catch (error) {
      _errorMessage = error.userMessage;
    } catch (error, stack) {
      debugPrint('Publish presence failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'Sin señal. Se intentará de nuevo en un momento.';
    } finally {
      _publishing = false;
      _notify();
    }
  }

  Future<void> _stopLocalOnly() async {
    await _stopTracking();
    _onRoute = false;
    await store.setOnRoute(false);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  DateTime _now() => now?.call() ?? DateTime.now();

  @override
  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    unawaited(_gpsSubscription?.cancel());
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
