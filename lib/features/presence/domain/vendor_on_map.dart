import 'package:dale_u/features/presence/domain/vendor_presence.dart';

/// Un vendedor en el mapa del comprador.
final class VendorOnMap {
  const VendorOnMap({
    required this.vendorUid,
    required this.name,
    required this.presence,
  });

  final String vendorUid;
  final String name;
  final VendorPresence presence;
}
