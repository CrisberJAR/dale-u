import 'package:dale_u/features/role/domain/entities/user_role.dart';

/// Cuenta tal como vive en Firestore. El rol lo manda la nube, no el teléfono.
final class AccountProfile {
  const AccountProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  AccountProfile copyWith({UserRole? role}) {
    return AccountProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      role: role ?? this.role,
    );
  }
}
