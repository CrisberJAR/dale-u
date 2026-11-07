import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';

class AssignRole {
  const AssignRole(this._repository);

  final RoleRepository _repository;

  Future<void> call({required String uid, required UserRole role}) {
    return _repository.assignRole(uid: uid, role: role);
  }
}
