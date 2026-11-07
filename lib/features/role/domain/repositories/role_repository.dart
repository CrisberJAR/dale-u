import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';

abstract class RoleRepository {
  /// Rol guardado en el teléfono. Solo para arrancar sin señal.
  Future<UserRole?> cachedRole(String uid);

  /// Lee la cuenta en la nube. Si no existe, la crea como cliente.
  Future<AccountProfile> ensureAccount(UserSession session);

  /// Solo para administradores.
  Future<List<AccountProfile>> listAccounts();

  /// Solo para administradores.
  Future<void> assignRole({required String uid, required UserRole role});
}
