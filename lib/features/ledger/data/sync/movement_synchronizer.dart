import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/sync/sync_cursor_store.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_remote_datasource.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:flutter/foundation.dart';

/// Empuja pendientes y trae remotos. Fallar no borra SQLite.
///
/// - Sube en lotes; si un lote falla, reintenta uno por uno para que un
///   movimiento malo no frene a los demás.
/// - Marca "subido" solo si el movimiento no cambió mientras subía.
/// - Baja solo lo nuevo (una consulta) y, una vez al día, todo.
/// - Si piden sincronizar mientras ya corre, vuelve a correr al terminar.
class MovementSynchronizer {
  MovementSynchronizer({
    required this.local,
    required this.remote,
    required this.listClientIds,
    this.cursors,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final MovementPendingStore local;
  final MovementRemoteDataSource remote;
  final Future<List<String>> Function(String vendorUid) listClientIds;

  /// `null`: siempre baja todo.
  final SyncCursorStore? cursors;
  final DateTime Function() now;

  static const batchSize = 400;

  /// Margen al pedir cambios: lo repetido no hace daño, lo perdido sí.
  static const overlap = Duration(minutes: 5);

  /// Tras bajar todo, el cursor arranca una hora atrás por si el reloj del
  /// teléfono va adelantado.
  static const fullPullSlack = Duration(hours: 1);

  bool _running = false;
  bool _again = false;

  Future<void> sync(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _pushPending(uid);
        await _pull(uid);
      } while (_again);
    } finally {
      _running = false;
      _again = false;
    }
  }

  Future<void> _pushPending(String vendorUid) async {
    final pending = await local.listPending(vendorUid);
    Object? lastError;
    for (var start = 0; start < pending.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, pending.length);
      final chunk = pending.sublist(start, end);
      try {
        await remote.upsertAll(chunk);
        for (final movement in chunk) {
          await local.markSynced(movement);
        }
      } catch (error) {
        debugPrint('Push batch failed: ${error.runtimeType}. One by one.');
        lastError = await _pushOneByOne(chunk) ?? lastError;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
  }

  Future<Object?> _pushOneByOne(List<Movement> chunk) async {
    Object? lastError;
    for (final movement in chunk) {
      try {
        await remote.upsert(movement);
        await local.markSynced(movement);
      } catch (error, stack) {
        lastError = error;
        debugPrint('Push movement failed: ${error.runtimeType}');
        debugPrint('$stack');
      }
    }
    return lastError;
  }

  Future<void> _pull(String vendorUid) async {
    final store = cursors;
    if (store == null) {
      await _pullFull(vendorUid);
      return;
    }
    final stamp = now().toUtc();
    final since = store.cursor(vendorUid);
    if (since == null || store.fullPullDue(vendorUid, stamp)) {
      await _pullFull(vendorUid);
      await store.saveCursor(vendorUid, stamp.subtract(fullPullSlack));
      await store.saveFullPull(vendorUid, stamp);
      return;
    }
    try {
      final changes = await remote.fetchChangedSince(
        vendorUid: vendorUid,
        since: since.subtract(overlap),
      );
      for (final movement in changes.movements) {
        await local.insertIfAbsent(movement);
      }
      final next = changes.cursor;
      if (next != null && next.isAfter(since)) {
        await store.saveCursor(vendorUid, next);
      }
    } on MovementDeltaUnavailable {
      await _pullFull(vendorUid);
    }
  }

  Future<void> _pullFull(String vendorUid) async {
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
