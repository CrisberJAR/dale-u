import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_remote_datasource.dart';
import 'package:flutter/foundation.dart';

/// Empuja pendientes y trae remotos. Fallar no borra SQLite.
class MovementSynchronizer {
  MovementSynchronizer({
    required this.local,
    required this.remote,
    required this.listClientIds,
  });

  final MovementPendingStore local;
  final MovementRemoteDataSource remote;
  final Future<List<String>> Function(String vendorUid) listClientIds;

  bool _running = false;

  Future<void> sync(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null || _running) return;
    _running = true;
    try {
      await _pushPending(uid);
      await _pullRemote(uid);
    } finally {
      _running = false;
    }
  }

  Future<void> _pushPending(String vendorUid) async {
    final pending = await local.listPending(vendorUid);
    Object? lastError;
    for (final movement in pending) {
      try {
        await remote.upsert(movement);
        await local.markSynced(movement.id);
      } catch (error, stack) {
        lastError = error;
        debugPrint('Push movement failed: ${error.runtimeType}');
        debugPrint('$stack');
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  Future<void> _pullRemote(String vendorUid) async {
    final clientIds = await listClientIds(vendorUid);
    for (final clientId in clientIds) {
      final remoteMovements = await remote.fetchByClient(
        vendorUid: vendorUid,
        clientId: clientId,
      );
      for (final movement in remoteMovements) {
        await local.insertIfAbsent(movement);
      }
    }
  }
}
