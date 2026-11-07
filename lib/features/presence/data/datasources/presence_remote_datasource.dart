import 'package:dale_u/features/presence/domain/vendor_presence.dart';

abstract class PresenceRemoteDataSource {
  Future<void> publish(String vendorUid, VendorPresence presence);

  /// Un tiro. El mapa lo usa al abrir; luego pasa a [watch].
  Future<VendorPresence?> fetch(String vendorUid);

  /// Solo mientras el comprador tiene el mapa abierto.
  Stream<VendorPresence?> watch(String vendorUid);
}
