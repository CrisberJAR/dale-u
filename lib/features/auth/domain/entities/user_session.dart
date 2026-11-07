import 'package:dale_u/core/security/input_sanitizer.dart';

/// Sesión autenticada. No incluye tokens: Firebase Auth los guarda en el
/// almacén seguro nativo (Keystore / Keychain).
final class UserSession {
  const UserSession({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  factory UserSession.fromProvider({
    required String uid,
    required String? email,
    required String? displayName,
    required String? photoUrl,
  }) {
    return UserSession(
      uid: uid.trim(),
      email: InputSanitizer.email(email),
      displayName: InputSanitizer.displayName(displayName),
      photoUrl: InputSanitizer.photoUrl(photoUrl),
    );
  }
}
