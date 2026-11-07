import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/invite_code.dart';
import 'package:uuid/uuid.dart';

abstract class ClientPendingStore {
  Future<List<Client>> listPending(String vendorUid);
  /// Marca subido solo si la ficha sigue igual a [pushed].
  Future<void> markSynced(Client pushed);
  Future<void> insertIfAbsent(Client client);
}

class ClientLocalDataSource implements ClientPendingStore {
  ClientLocalDataSource(this.database, {this.uuid = const Uuid()});

  final AppDatabase database;
  final Uuid uuid;

  Future<List<Client>> listByVendor(String vendorUid) async {
    final rows = await database.db.query(
      'clients',
      where: 'vendor_uid = ? AND active = ?',
      whereArgs: [vendorUid, 1],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Client>> listPending(String vendorUid) async {
    final rows = await database.db.query(
      'clients',
      where: 'vendor_uid = ? AND pending_sync = ?',
      whereArgs: [vendorUid, 1],
    );
    return rows.map(_fromRow).toList();
  }

  /// Cada cambio local mueve `updated_at`: si no coincide, el vendedor la
  /// editó mientras subía y sigue pendiente.
  @override
  Future<void> markSynced(Client pushed) async {
    await database.db.update(
      'clients',
      {'pending_sync': 0},
      where: 'id = ? AND updated_at = ? AND invite_code = ?',
      whereArgs: [
        pushed.id,
        pushed.updatedAt.millisecondsSinceEpoch,
        pushed.inviteCode,
      ],
    );
  }

  @override
  Future<void> insertIfAbsent(Client client) async {
    final existing = await database.db.query(
      'clients',
      columns: ['id', 'pending_sync'],
      where: 'id = ?',
      whereArgs: [client.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.db.insert('clients', _toRow(client));
      return;
    }
    final pending = (existing.first['pending_sync'] as int?) == 1;
    if (pending) return;
    await database.db.update(
      'clients',
      {
        'name': client.name,
        'phone': client.phone,
        'updated_at': client.updatedAt.millisecondsSinceEpoch,
        'active': client.active ? 1 : 0,
        'invite_code': client.inviteCode,
        'linked_uid': client.linkedUid,
        'pending_sync': client.pendingSync ? 1 : 0,
        'latitude': client.latitude,
        'longitude': client.longitude,
      },
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<Client> insert({
    required String vendorUid,
    required String name,
    required String phone,
  }) async {
    final now = DateTime.now();
    final client = Client(
      id: uuid.v4(),
      vendorUid: vendorUid,
      name: name,
      phone: phone,
      createdAt: now,
      updatedAt: now,
      pendingSync: true,
      active: true,
      inviteCode: await _uniqueInviteCode(),
    );
    await database.db.insert('clients', _toRow(client));
    return client;
  }

  Future<Client> updateDetails({
    required String vendorUid,
    required String id,
    required String name,
    required String phone,
  }) async {
    final now = DateTime.now();
    final count = await database.db.update(
      'clients',
      {
        'name': name,
        'phone': phone,
        'updated_at': now.millisecondsSinceEpoch,
        'pending_sync': 1,
      },
      where: 'id = ? AND vendor_uid = ? AND active = ?',
      whereArgs: [id, vendorUid, 1],
    );
    if (count == 0) {
      throw const ClientException('No se encontró el cliente.');
    }
    return _mustGet(id);
  }

  Future<Client> updateHouse({
    required String vendorUid,
    required String id,
    required double? latitude,
    required double? longitude,
  }) async {
    final now = DateTime.now();
    final count = await database.db.update(
      'clients',
      {
        'latitude': latitude,
        'longitude': longitude,
        'updated_at': now.millisecondsSinceEpoch,
        'pending_sync': 1,
      },
      where: 'id = ? AND vendor_uid = ? AND active = ?',
      whereArgs: [id, vendorUid, 1],
    );
    if (count == 0) {
      throw const ClientException('No se encontró el cliente.');
    }
    return _mustGet(id);
  }

  Future<void> deactivate({
    required String vendorUid,
    required String id,
  }) async {
    final now = DateTime.now();
    final count = await database.db.update(
      'clients',
      {
        'active': 0,
        'updated_at': now.millisecondsSinceEpoch,
        'pending_sync': 1,
      },
      where: 'id = ? AND vendor_uid = ? AND active = ?',
      whereArgs: [id, vendorUid, 1],
    );
    if (count == 0) {
      throw const ClientException('No se encontró el cliente.');
    }
  }

  Future<List<String>> listIdsByVendor(String vendorUid) async {
    final rows = await database.db.query(
      'clients',
      columns: ['id'],
      where: 'vendor_uid = ?',
      whereArgs: [vendorUid],
    );
    return rows.map((row) => row['id']! as String).toList();
  }

  Future<List<Client>> listInactiveByVendor(String vendorUid) async {
    final rows = await database.db.query(
      'clients',
      where: 'vendor_uid = ? AND active = ?',
      whereArgs: [vendorUid, 0],
      orderBy: 'updated_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> deleteById({
    required String vendorUid,
    required String id,
  }) async {
    await database.db.delete(
      'clients',
      where: 'id = ? AND vendor_uid = ? AND active = ?',
      whereArgs: [id, vendorUid, 0],
    );
  }

  Future<String> _uniqueInviteCode() async {
    for (var i = 0; i < 16; i++) {
      final code = InviteCode.generate();
      final existing = await database.db.query(
        'clients',
        columns: ['id'],
        where: 'invite_code = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (existing.isEmpty) return code;
    }
    throw const ClientException('No se pudo crear el código de vinculación.');
  }

  Future<Client> _mustGet(String id) async {
    final rows = await database.db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const ClientException('No se encontró el cliente.');
    }
    return _fromRow(rows.first);
  }

  Map<String, Object?> _toRow(Client client) {
    return {
      'id': client.id,
      'vendor_uid': client.vendorUid,
      'name': client.name,
      'phone': client.phone,
      'created_at': client.createdAt.millisecondsSinceEpoch,
      'updated_at': client.updatedAt.millisecondsSinceEpoch,
      'pending_sync': client.pendingSync ? 1 : 0,
      'active': client.active ? 1 : 0,
      'invite_code': client.inviteCode,
      'linked_uid': client.linkedUid,
      'latitude': client.latitude,
      'longitude': client.longitude,
    };
  }

  Client _fromRow(Map<String, Object?> row) {
    final house = _houseOf(row);
    return Client(
      id: row['id']! as String,
      vendorUid: row['vendor_uid']! as String,
      name: row['name']! as String,
      phone: row['phone']! as String,
      createdAt: fromEpochMillis(row['created_at']! as int),
      updatedAt: fromEpochMillis(row['updated_at']! as int),
      pendingSync: (row['pending_sync']! as int) == 1,
      active: (row['active'] as int?) != 0,
      inviteCode: (row['invite_code'] as String?) ?? '',
      linkedUid: (row['linked_uid'] as String?) ?? '',
      latitude: house.$1,
      longitude: house.$2,
    );
  }

  static (double?, double?) _houseOf(Map<String, Object?> row) {
    final lat = _asCoord(row['latitude']);
    final lng = _asCoord(row['longitude']);
    if (lat == null || lng == null) return (null, null);
    return (lat, lng);
  }

  static double? _asCoord(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }
}
