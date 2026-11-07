import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/features/auth/data/gateways/google_sign_in_gateway.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Intercambia el idToken de Google por una sesión de Firebase Auth.
/// El token se usa una sola vez y no se persiste ni se registra en logs.
class GoogleAuthRemoteDataSource {
  GoogleAuthRemoteDataSource({
    required this.firebaseAuth,
    required this.googleSignIn,
  });

  final FirebaseAuth firebaseAuth;
  final GoogleSignInGateway googleSignIn;

  Stream<UserSession?> authStateChanges() {
    return firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return UserSession.fromProvider(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    });
  }

  Future<UserSession> signInWithGoogle() async {
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthFailure.missingToken();
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await firebaseAuth.signInWithCredential(
      credential,
    );
    final user = userCredential.user;
    if (user == null) {
      throw const AuthFailure.unknown();
    }

    return UserSession.fromProvider(
      uid: user.uid,
      email: user.email ?? account.email,
      displayName: user.displayName ?? account.displayName,
      photoUrl: user.photoURL ?? account.photoUrl,
    );
  }

  Future<void> signOut() async {
    await Future.wait<void>([
      firebaseAuth.signOut(),
      googleSignIn.signOut(),
    ]);
  }
}
