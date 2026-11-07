final class Client {
  const Client({
    required this.id,
    required this.vendorUid,
    required this.name,
    required this.phone,
    required this.createdAt,
    required this.updatedAt,
    this.pendingSync = true,
    this.active = true,
    this.inviteCode = '',
    this.linkedUid = '',
    this.latitude,
    this.longitude,
    this.balanceCents,
  });

  final String id;
  final String vendorUid;
  final String name;
  final String phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// true = aún no se subió a Firestore.
  final bool pendingSync;
  final bool active;
  final String inviteCode;
  final String linkedUid;

  /// Pin de la casa. Los dos o ninguno.
  final double? latitude;
  final double? longitude;

  /// Saldo que calcula la Cloud Function en la nube. Solo lo usa el
  /// comprador (una lectura). El vendedor suma en su teléfono, sin señal.
  final int? balanceCents;

  bool get isLinked => linkedUid.isNotEmpty;

  bool get hasHousePin => latitude != null && longitude != null;

  static const _absent = Object();

  Client copyWith({
    String? name,
    String? phone,
    DateTime? updatedAt,
    bool? pendingSync,
    bool? active,
    String? inviteCode,
    String? linkedUid,
    Object? latitude = _absent,
    Object? longitude = _absent,
  }) {
    return Client(
      id: id,
      vendorUid: vendorUid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      active: active ?? this.active,
      inviteCode: inviteCode ?? this.inviteCode,
      linkedUid: linkedUid ?? this.linkedUid,
      latitude: identical(latitude, _absent)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _absent)
          ? this.longitude
          : longitude as double?,
    );
  }
}
