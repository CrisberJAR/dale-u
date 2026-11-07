import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:uuid/uuid.dart';

abstract class MovementPendingStore {
  Future<List<Movement>> listPending(String vendorUid);
  Future<void> markSynced(Movement pushed);
  Future<void> insertIfAbsent(Movement movement);
}

class MovementLocalDataSource implements MovementPendingStore {
  MovementLocalDataSource(this.database, {this.uuid = const Uuid()});

  final AppDatabase database;
  final Uuid uuid;

  Future<Movement> insert({
    required String vendorUid,
    required String clientId,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    final now = DateTime.now();
    final movement = Movement(
      id: uuid.v4(),
      vendorUid: vendorUid,
      clientId: clientId,
      kind: kind,
      amountCents: amountCents,
      occurredAt: occurredAt,
      createdAt: now,
      pendingSync: true,
    );
    await database.db.insert('movements', {
      'id': movement.id,
      'vendor_uid': movement.vendorUid,
      'client_id': movement.clientId,
      'kind': movement.kind.name,
      'amount_cents': movement.amountCents,
      'occurred_at': movement.occurredAt.millisecondsSinceEpoch,
      'created_at': movement.createdAt.millisecondsSinceEpoch,
      'pending_sync': 1,
      'voided': 0,
    });
    return movement;
  }

  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    final rows = await database.db.query(
      'movements',
      where: 'vendor_uid = ? AND client_id = ?',
      whereArgs: [vendorUid, clientId],
      orderBy: 'occurred_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    final count = await database.db.update(
      'movements',
      {
        'kind': kind.name,
        'amount_cents': amountCents,
        'occurred_at': occurredAt.toUtc().millisecondsSinceEpoch,
        'pending_sync': 1,
      },
      where: 'id = ? AND vendor_uid = ? AND voided = ?',
      whereArgs: [id, vendorUid, 0],
    );
    if (count == 0) {
      throw const LedgerException('No se encontró el movimiento.');
    }
    return _mustGet(id);
  }

  Future<void> voidById({
    required String vendorUid,
    required String id,
  }) async {
    final count = await database.db.update(
      'movements',
      {
        'voided': 1,
        'pending_sync': 1,
      },
      where: 'id = ? AND vendor_uid = ? AND voided = ?',
      whereArgs: [id, vendorUid, 0],
    );
    if (count == 0) {
      throw const LedgerException('No se encontró el movimiento.');
    }
  }

  Future<List<Movement>> listByDay({
    required String vendorUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await database.db.query(
      'movements',
      where:
          'vendor_uid = ? AND voided = 0 AND occurred_at >= ? AND occurred_at < ?',
      whereArgs: [
        vendorUid,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'occurred_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Map<String, int>> balancesByVendor(String vendorUid) async {
    final rows = await database.db.rawQuery(
      '''
      SELECT client_id,
             SUM(CASE WHEN kind = 'fiado' THEN amount_cents ELSE -amount_cents END) AS balance
      FROM movements
      WHERE vendor_uid = ? AND voided = 0
      GROUP BY client_id
      ''',
      [vendorUid],
    );
    final balances = <String, int>{};
    for (final row in rows) {
      final clientId = row['client_id'] as String?;
      if (clientId == null || clientId.isEmpty) continue;
      final balance = row['balance'];
      balances[clientId] = balance is int
          ? balance
          : (balance as num?)?.toInt() ?? 0;
    }
    return balances;
  }

  Future<DateTime?> lastOccurredAt({
    required String vendorUid,
    required String clientId,
  }) async {
    final rows = await database.db.rawQuery(
      '''
      SELECT MAX(occurred_at) AS last_at FROM movements
      WHERE vendor_uid = ? AND client_id = ?
      ''',
      [vendorUid, clientId],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['last_at'];
    if (value is int) return fromEpochMillis(value);
    if (value is num) return fromEpochMillis(value.toInt());
    return null;
  }

  Future<void> deleteByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    await database.db.delete(
      'movements',
      where: 'vendor_uid = ? AND client_id = ?',
      whereArgs: [vendorUid, clientId],
    );
  }

  @override
  Future<List<Movement>> listPending(String vendorUid) async {
    final rows = await database.db.query(
      'movements',
      where: 'vendor_uid = ? AND pending_sync = ?',
      whereArgs: [vendorUid, 1],
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countPending(String vendorUid) async {
    final rows = await database.db.rawQuery(
      '''
      SELECT COUNT(*) AS c FROM movements
      WHERE vendor_uid = ? AND pending_sync = 1
      ''',
      [vendorUid],
    );
    if (rows.isEmpty) return 0;
    final value = rows.first['c'];
    if (value is int) return value;
    return (value as num?)?.toInt() ?? 0;
  }

  /// Marca subido solo si la fila sigue igual a lo que se subió. Si el
  /// vendedor la editó mientras subía, queda pendiente y sube en la próxima.
  @override
  Future<void> markSynced(Movement pushed) async {
    await database.db.update(
      'movements',
      {'pending_sync': 0},
      where: 'id = ? AND kind = ? AND amount_cents = ? AND occurred_at = ? '
          'AND voided = ?',
      whereArgs: [
        pushed.id,
        pushed.kind.name,
        pushed.amountCents,
        pushed.occurredAt.millisecondsSinceEpoch,
        pushed.voided ? 1 : 0,
      ],
    );
  }

  @override
  Future<void> insertIfAbsent(Movement movement) async {
    final existing = await database.db.query(
      'movements',
      columns: ['id', 'pending_sync'],
      where: 'id = ?',
      whereArgs: [movement.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.db.insert('movements', _toRow(movement));
      return;
    }
    final pending = (existing.first['pending_sync'] as int?) == 1;
    if (pending) return;
    await database.db.update(
      'movements',
      {
        'kind': movement.kind.name,
        'amount_cents': movement.amountCents,
        'occurred_at': movement.occurredAt.millisecondsSinceEpoch,
        'voided': movement.voided ? 1 : 0,
        'pending_sync': movement.pendingSync ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [movement.id],
    );
  }

  Map<String, Object?> _toRow(Movement movement) {
    return {
      'id': movement.id,
      'vendor_uid': movement.vendorUid,
      'client_id': movement.clientId,
      'kind': movement.kind.name,
      'amount_cents': movement.amountCents,
      'occurred_at': movement.occurredAt.millisecondsSinceEpoch,
      'created_at': movement.createdAt.millisecondsSinceEpoch,
      'pending_sync': movement.pendingSync ? 1 : 0,
      'voided': movement.voided ? 1 : 0,
    };
  }

  Future<Movement> _mustGet(String id) async {
    final rows = await database.db.query(
      'movements',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const LedgerException('No se encontró el movimiento.');
    }
    return _fromRow(rows.first);
  }

  Movement _fromRow(Map<String, Object?> row) {
    final kind = MovementKind.tryParse(row['kind']! as String);
    if (kind == null) {
      throw const LedgerException('Movimiento inválido.');
    }
    return Movement(
      id: row['id']! as String,
      vendorUid: row['vendor_uid']! as String,
      clientId: row['client_id']! as String,
      kind: kind,
      amountCents: row['amount_cents']! as int,
      occurredAt: fromEpochMillis(row['occurred_at']! as int),
      createdAt: fromEpochMillis(row['created_at']! as int),
      pendingSync: (row['pending_sync']! as int) == 1,
      voided: (row['voided'] as int?) == 1,
    );
  }
}
