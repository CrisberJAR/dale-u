import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';

class LoadAccount {
  const LoadAccount(this._repository);

  final RoleRepository _repository;

  Future<AccountProfile> call(UserSession session) {
    return _repository.ensureAccount(session);
  }

  Future<UserRole?> cached(String uid) => _repository.cachedRole(uid);
}
