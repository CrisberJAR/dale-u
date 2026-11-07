import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// Empuja pendientes y trae remotos. Fallar no borra SQLite.
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

  Future<void> sync(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null || _running) return;
    _running = true;
    try {
      await _publishName(uid);
      await _pushPending(uid);
      await _pullRemote(uid);
      final hook = afterPull;
      if (hook != null) await hook(uid);
    } finally {
      _running = false;
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
        await local.markSynced(client.id);
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
