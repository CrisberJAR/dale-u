import 'dart:async';

import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';
import 'package:dale_u/features/role/domain/usecases/load_account.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRoleRepository implements RoleRepository {
  _FakeRoleRepository({this.role = UserRole.cliente, this.cached});

  UserRole role;
  UserRole? cached;
  bool cloudFails = false;
  int ensureCalls = 0;

  @override
  Future<UserRole?> cachedRole(String uid) async => cached;

  @override
  Future<AccountProfile> ensureAccount(UserSession session) async {
    ensureCalls++;
    if (cloudFails) {
      throw const RoleException('Sin señal para confirmar tu cuenta.');
    }
    return AccountProfile(
      uid: session.uid,
      email: session.email,
      displayName: session.displayName,
      role: role,
    );
  }

  @override
  Future<List<AccountProfile>> listAccounts() async => const [];

  @override
  Future<void> assignRole({required String uid, required UserRole role}) async {}
}

const _session = UserSession(
  uid: 'uid123',
  email: 'ana@pan.com',
  displayName: 'Ana',
);

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.stream);

  final Stream<UserSession?> stream;

  @override
  Stream<UserSession?> observeAuthState() => stream;

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

RoleViewModel _build(
  _FakeRoleRepository repository,
  Stream<UserSession?> stream,
) {
  return RoleViewModel(
    observeAuthState: ObserveAuthState(_FakeAuthRepository(stream)),
    loadAccount: LoadAccount(repository),
  );
}

void main() {
  test('toma el rol de la nube, no del teléfono', () async {
    final repository = _FakeRoleRepository(role: UserRole.vendedor);
    final viewModel = _build(
      repository,
      Stream<UserSession?>.value(_session),
    );

    await Future<void>.delayed(Duration.zero);

    expect(viewModel.status, RoleStatus.ready);
    expect(viewModel.role, UserRole.vendedor);
    expect(viewModel.canSell, isTrue);
    expect(viewModel.isAdmin, isFalse);
    expect(viewModel.isFromCache, isFalse);

    viewModel.dispose();
  });

  test('el admin puede vender y nombrar cuentas', () async {
    final repository = _FakeRoleRepository(role: UserRole.admin);
    final viewModel = _build(
      repository,
      Stream<UserSession?>.value(_session),
    );

    await Future<void>.delayed(Duration.zero);

    expect(viewModel.canSell, isTrue);
    expect(viewModel.isAdmin, isTrue);

    viewModel.dispose();
  });

  test('sin señal usa el rol recordado y avisa que viene del teléfono', () async {
    final repository = _FakeRoleRepository(cached: UserRole.vendedor)
      ..cloudFails = true;
    final viewModel = _build(
      repository,
      Stream<UserSession?>.value(_session),
    );

    await Future<void>.delayed(Duration.zero);

    expect(viewModel.status, RoleStatus.ready);
    expect(viewModel.role, UserRole.vendedor);
    expect(viewModel.isFromCache, isTrue);

    viewModel.dispose();
  });

  test('sin señal y sin recuerdo pide reintentar', () async {
    final repository = _FakeRoleRepository()..cloudFails = true;
    final viewModel = _build(
      repository,
      Stream<UserSession?>.value(_session),
    );

    await Future<void>.delayed(Duration.zero);

    expect(viewModel.status, RoleStatus.failed);
    expect(viewModel.role, isNull);
    expect(viewModel.errorMessage, contains('Sin señal'));

    repository.cloudFails = false;
    repository.role = UserRole.cliente;
    await viewModel.retry();

    expect(viewModel.status, RoleStatus.ready);
    expect(viewModel.role, UserRole.cliente);
    expect(repository.ensureCalls, 2);

    viewModel.dispose();
  });

  test('al cerrar sesión se queda sin rol', () async {
    final controller = StreamController<UserSession?>();
    final repository = _FakeRoleRepository(role: UserRole.vendedor);
    final viewModel = _build(repository, controller.stream);

    controller.add(_session);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.role, UserRole.vendedor);

    controller.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.status, RoleStatus.none);
    expect(viewModel.role, isNull);
    expect(viewModel.canSell, isFalse);

    viewModel.dispose();
    await controller.close();
  });
}
