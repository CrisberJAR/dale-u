import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';

abstract class AccountRemoteDataSource {
  Future<AccountProfile> ensureAccount(UserSession session);

  Future<List<AccountProfile>> listAccounts();

  Future<void> assignRole({required String uid, required UserRole role});
}
