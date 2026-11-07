import 'package:dale_u/features/client/domain/entities/client.dart';

abstract class ClientRepository {
  Future<List<Client>> listByVendor(String vendorUid);

  Future<Client> register({
    required String vendorUid,
    required String name,
    required String phone,
  });

  Future<Client> updateDetails({
    required String vendorUid,
    required String id,
    required String name,
    required String phone,
  });

  Future<Client> updateHouse({
    required String vendorUid,
    required String id,
    required double? latitude,
    required double? longitude,
  });

  Future<void> deactivate({
    required String vendorUid,
    required String id,
  });

  /// Sube pendientes y baja remotos. No debe lanzar al UI.
  Future<void> syncPending(String vendorUid);
}
