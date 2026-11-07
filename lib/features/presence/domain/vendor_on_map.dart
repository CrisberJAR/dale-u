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

/// Un vendedor que publicó su punto. El nombre se resuelve aparte.
final class VendorOnRoute {
  const VendorOnRoute({required this.vendorUid, required this.presence});

  final String vendorUid;
  final VendorPresence presence;
}
