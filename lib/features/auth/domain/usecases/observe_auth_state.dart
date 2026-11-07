import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';

class ObserveAuthState {
  const ObserveAuthState(this._repository);

  final AuthRepository _repository;

  Stream<UserSession?> call() => _repository.observeAuthState();
}
