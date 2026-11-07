import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/data/datasources/account_remote_datasource.dart';
import 'package:dale_u/features/role/data/datasources/role_local_datasource.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';

class RoleRepositoryImpl implements RoleRepository {
  RoleRepositoryImpl({required this.local, required this.remote});

  final RoleLocalDataSource local;
  final AccountRemoteDataSource remote;

  @override
  Future<UserRole?> cachedRole(String uid) => local.readRole(uid);

  @override
  Future<AccountProfile> ensureAccount(UserSession session) async {
    final account = await remote.ensureAccount(session);
    // El caché solo sirve para abrir la pantalla correcta sin señal.
    await local.saveRole(uid: account.uid, role: account.role);
    return account;
  }

  @override
  Future<List<AccountProfile>> listAccounts() => remote.listAccounts();

  @override
  Future<void> assignRole({required String uid, required UserRole role}) {
    return remote.assignRole(uid: uid, role: role);
  }
}
