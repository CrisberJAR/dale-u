/// Aviso del vendedor al comprador vinculado. Un documento por vendedor.
final class VendorNotice {
  const VendorNotice({
    required this.vendorUid,
    required this.vendorName,
    required this.body,
    required this.createdAt,
  });

  final String vendorUid;
  final String vendorName;
  final String body;
  final DateTime createdAt;

  String get headline {
    final name = vendorName.trim();
    if (name.isEmpty) return 'Tu panadero avisa';
    return '$name avisa';
  }
}
