import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/sync/movement_synchronizer.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class MovementRepositoryImpl implements MovementRepository {
  MovementRepositoryImpl(this._local, {this.synchronizer});

  final MovementLocalDataSource _local;
  final MovementSynchronizer? synchronizer;

  @override
  Future<Movement> record(Movement movement) {
    return _local.insert(
      vendorUid: movement.vendorUid,
      clientId: movement.clientId,
      kind: movement.kind,
      amountCents: movement.amountCents,
      occurredAt: movement.occurredAt,
    );
  }

  @override
  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  }) {
    return _local.listByClient(vendorUid: vendorUid, clientId: clientId);
  }

  @override
  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) {
    return _local.updateDetails(
      vendorUid: vendorUid,
      id: id,
      kind: kind,
      amountCents: amountCents,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<void> voidById({
    required String vendorUid,
    required String id,
  }) {
    return _local.voidById(vendorUid: vendorUid, id: id);
  }

  @override
  Future<Map<String, int>> balancesByVendor(String vendorUid) {
    return _local.balancesByVendor(vendorUid);
  }

  @override
  Future<List<Movement>> listByDay({
    required String vendorUid,
    required DateTime start,
    required DateTime end,
  }) {
    return _local.listByDay(
      vendorUid: vendorUid,
      start: start,
      end: end,
    );
  }

  @override
  Future<void> syncPending(String vendorUid) async {
    await synchronizer?.sync(vendorUid);
  }
}
