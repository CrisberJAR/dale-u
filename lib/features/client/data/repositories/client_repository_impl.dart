import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/sync/client_synchronizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class ClientRepositoryImpl implements ClientRepository {
  ClientRepositoryImpl({
    required this.local,
    required this.synchronizer,
  });

  final ClientLocalDataSource local;
  final ClientSynchronizer synchronizer;

  @override
  Future<List<Client>> listByVendor(String vendorUid) {
    return local.listByVendor(vendorUid);
  }

  @override
  Future<Client> register({
    required String vendorUid,
    required String name,
    required String phone,
  }) {
    return local.insert(
      vendorUid: vendorUid,
      name: name,
      phone: phone,
    );
  }

  @override
  Future<Client> updateDetails({
    required String vendorUid,
    required String id,
    required String name,
    required String phone,
  }) {
    return local.updateDetails(
      vendorUid: vendorUid,
      id: id,
      name: name,
      phone: phone,
    );
  }

  @override
  Future<Client> updateHouse({
    required String vendorUid,
    required String id,
    required double? latitude,
    required double? longitude,
  }) {
    return local.updateHouse(
      vendorUid: vendorUid,
      id: id,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<void> deactivate({
    required String vendorUid,
    required String id,
  }) {
    return local.deactivate(vendorUid: vendorUid, id: id);
  }

  @override
  Future<void> syncPending(String vendorUid) {
    return synchronizer.sync(vendorUid);
  }
}
