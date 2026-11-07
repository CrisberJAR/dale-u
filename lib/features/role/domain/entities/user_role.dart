/// Roles permitidos. Cualquier otro texto se descarta (sin inyección).
enum UserRole {
  cliente,
  vendedor,
  admin;

  String get storageValue => name;

  String get label => switch (this) {
    UserRole.cliente => 'Cliente',
    UserRole.vendedor => 'Vendedor',
    UserRole.admin => 'Administrador',
  };

  /// Vendedor y admin trabajan la ruta. El cliente solo consulta.
  bool get canSell => this != UserRole.cliente;

  bool get canManageAccounts => this == UserRole.admin;

  /// Solo acepta los valores del enum. Basura → sin rol.
  static UserRole? parse(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'cliente' => UserRole.cliente,
      'vendedor' => UserRole.vendedor,
      'admin' => UserRole.admin,
      _ => null,
    };
  }
}
