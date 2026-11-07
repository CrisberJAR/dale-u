import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';
import 'package:dale_u/features/role/domain/usecases/assign_role.dart';
import 'package:dale_u/features/role/domain/usecases/list_accounts.dart';
import 'package:dale_u/features/role/presentation/viewmodels/admin_accounts_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRoleRepository implements RoleRepository {
  final accounts = <AccountProfile>[];
  final assigned = <String, UserRole>{};
  bool assignFails = false;

  @override
  Future<UserRole?> cachedRole(String uid) async => null;

  @override
  Future<AccountProfile> ensureAccount(UserSession session) {
    throw UnimplementedError();
  }

  @override
  Future<List<AccountProfile>> listAccounts() async => accounts;

  @override
  Future<void> assignRole({
    required String uid,
    required UserRole role,
  }) async {
    if (assignFails) {
      throw const RoleException('Firebase no dejó cambiar el rol.');
    }
    assigned[uid] = role;
  }
}

const _luis = AccountProfile(
  uid: 'uid999',
  email: 'luis@pan.com',
  displayName: 'Luis',
  role: UserRole.cliente,
);

const _ana = AccountProfile(
  uid: 'uid123',
  email: 'ana@pan.com',
  displayName: 'Ana',
  role: UserRole.admin,
);

AdminAccountsViewModel _build(_FakeRoleRepository repository) {
  return AdminAccountsViewModel(
    listAccounts: ListAccounts(repository),
    assignRole: AssignRole(repository),
  );
}

void main() {
  test('lista las cuentas y filtra por nombre o correo', () async {
    final repository = _FakeRoleRepository()..accounts.addAll([_ana, _luis]);
    final viewModel = _build(repository);

    await viewModel.refresh();
    expect(viewModel.visibleAccounts.length, 2);

    viewModel.setQuery('lu');
    expect(viewModel.visibleAccounts.single.uid, 'uid999');

    viewModel.setQuery('ana@');
    expect(viewModel.visibleAccounts.single.uid, 'uid123');

    viewModel.dispose();
  });

  test('sube un cliente a vendedor y refleja el cambio en la lista', () async {
    final repository = _FakeRoleRepository()..accounts.addAll([_luis]);
    final viewModel = _build(repository);
    await viewModel.refresh();

    final result = await viewModel.changeRole(
      account: _luis,
      role: UserRole.vendedor,
    );

    expect(result.ok, isTrue);
    expect(result.message, 'Luis ahora es Vendedor.');
    expect(repository.assigned['uid999'], UserRole.vendedor);
    expect(viewModel.visibleAccounts.single.role, UserRole.vendedor);

    viewModel.dispose();
  });

  test('si Firebase rechaza el cambio, el rol no se mueve', () async {
    final repository = _FakeRoleRepository()
      ..accounts.addAll([_luis])
      ..assignFails = true;
    final viewModel = _build(repository);
    await viewModel.refresh();

    final result = await viewModel.changeRole(
      account: _luis,
      role: UserRole.admin,
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('no dejó cambiar el rol'));
    expect(viewModel.visibleAccounts.single.role, UserRole.cliente);
    expect(viewModel.errorMessage, isNotNull);

    viewModel.dispose();
  });

  test('no llama a Firebase si el rol ya es el mismo', () async {
    final repository = _FakeRoleRepository()..accounts.addAll([_luis]);
    final viewModel = _build(repository);
    await viewModel.refresh();

    final result = await viewModel.changeRole(
      account: _luis,
      role: UserRole.cliente,
    );

    expect(result.ok, isTrue);
    expect(repository.assigned, isEmpty);

    viewModel.dispose();
  });
}
