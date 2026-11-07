import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// Empuja pendientes y trae remotos. Fallar no borra SQLite.
///
/// Marca "subido" solo si la ficha no cambió mientras subía, y si piden
/// sincronizar mientras ya corre, vuelve a correr al terminar.
class ClientSynchronizer {
  ClientSynchronizer({
    required this.local,
    required this.remote,
    this.afterPull,
  });

  final ClientPendingStore local;
  final ClientRemoteDataSource remote;
  final Future<void> Function(String vendorUid)? afterPull;

  bool _running = false;
  bool _again = false;
  Future<void>? _inFlight;

  /// Si ya corre, espera a que termine (con la vuelta extra incluida):
  /// quien sincroniza movimientos justo después necesita los clientes ya
  /// en SQLite, o la bajada completa de movimientos sale vacía.
  Future<void> sync(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return;
    if (_running) {
      _again = true;
      await _inFlight;
      return;
    }
    _running = true;
    final run = _run(uid);
    _inFlight = run;
    try {
      await run;
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _run(String uid) async {
    try {
      await _publishName(uid);
      do {
        _again = false;
        await _pushPending(uid);
        await _pullRemote(uid);
      } while (_again);
      final hook = afterPull;
      if (hook != null) await hook(uid);
    } finally {
      _running = false;
      _again = false;
    }
  }

  /// Si falla, la ruta sigue: el comprador solo vería "Tu vendedor".
  Future<void> _publishName(String vendorUid) async {
    try {
      await remote.publishVendorName(vendorUid);
    } catch (error) {
      debugPrint('Publish vendor name failed: ${error.runtimeType}');
    }
  }

  Future<void> _pushPending(String vendorUid) async {
    final pending = await local.listPending(vendorUid);
    Object? lastError;
    for (final client in pending) {
      try {
        await remote.upsert(client);
        await local.markSynced(client);
      } catch (error, stack) {
        lastError = error;
        debugPrint('Push client failed: ${error.runtimeType}');
        debugPrint('$stack');
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  Future<void> _pullRemote(String vendorUid) async {
    final remoteClients = await remote.fetchByVendor(vendorUid);
    for (final client in remoteClients) {
      await local.insertIfAbsent(client);
    }
  }
}
