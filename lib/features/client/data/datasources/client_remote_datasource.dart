import 'package:dale_u/features/client/domain/entities/client.dart';

abstract class ClientRemoteDataSource {
  Future<void> upsert(Client client);

  Future<List<Client>> fetchByVendor(String vendorUid);

  /// Publica el nombre del vendedor en `vendors/{uid}` para que sus
  /// compradores sepan a quién le deben. Lo único público del vendedor.
  Future<void> publishVendorName(String vendorUid);

  /// Borra ficha, invitación y movimientos en la nube. Solo la purga.
  Future<void> deleteCascade({
    required String vendorUid,
    required String clientId,
    required String inviteCode,
  });
}
