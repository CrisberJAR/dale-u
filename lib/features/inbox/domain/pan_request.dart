/// Recado fijo. Un documento por comprador; no es un chat.
final class PanRequest {
  const PanRequest({
    required this.buyerUid,
    required this.clientId,
    required this.clientName,
    required this.createdAt,
    this.seen = false,
  });

  final String buyerUid;
  final String clientId;
  final String clientName;
  final DateTime createdAt;
  final bool seen;

  String get label {
    final name = clientName.trim();
    if (name.isEmpty) return 'Un cliente te pidió pan.';
    return '$name te pidió pan.';
  }
}
