import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';

class ListAccounts {
  const ListAccounts(this._repository);

  final RoleRepository _repository;

  Future<List<AccountProfile>> call() => _repository.listAccounts();
}
