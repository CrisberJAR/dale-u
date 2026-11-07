import 'package:google_sign_in/google_sign_in.dart';

/// Aísla el SDK de Google para no acoplar el datasource al singleton.
abstract class GoogleSignInGateway {
  Future<void> initialize({
    required String serverClientId,
    String? clientId,
  });

  Future<GoogleSignInAccount> authenticate();

  Future<void> signOut();
}

class GoogleSignInGatewayImpl implements GoogleSignInGateway {
  @override
  Future<void> initialize({
    required String serverClientId,
    String? clientId,
  }) {
    return GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
      clientId: clientId,
    );
  }

  @override
  Future<GoogleSignInAccount> authenticate() {
    return GoogleSignIn.instance.authenticate();
  }

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
}
