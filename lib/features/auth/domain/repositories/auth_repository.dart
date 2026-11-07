import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';

abstract class AuthRepository {
  Stream<UserSession?> observeAuthState();
  Future<Result<UserSession>> signInWithGoogle();
  Future<Result<void>> signOut();
}
