import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/role/data/datasources/account_remote_datasource.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';

/// users/{uid}. Las reglas solo dejan al admin cambiar el rol.
class FirestoreAccountRemoteDataSource implements AccountRemoteDataSource {
  FirestoreAccountRemoteDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);

  CollectionReference<Map<String, dynamic>> get _col =>
      firestore.collection('users');

  @override
  Future<AccountProfile> ensureAccount(UserSession session) async {
    final uid = InputSanitizer.uid(session.uid);
    if (uid == null) {
      throw const RoleException('Sesión inválida. Vuelve a entrar.');
    }
    final email = InputSanitizer.email(session.email);
    final displayName = InputSanitizer.displayName(session.displayName);

    try {
      final snapshot = await _col.doc(uid).get().timeout(_timeout);
      final data = snapshot.data();
      final role = UserRole.parse(data?['role'] as String?);
      if (snapshot.exists && role != null) {
        return AccountProfile(
          uid: uid,
          email: InputSanitizer.email(data?['email'] as String?),
          displayName: InputSanitizer.displayName(
            data?['displayName'] as String?,
          ),
          role: role,
        );
      }

      // Primera vez: siempre cliente. Solo un admin puede subir el rol.
      await _col.doc(uid).set({
        'role': UserRole.cliente.storageValue,
        'email': email,
        'displayName': displayName,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(_timeout);
      return AccountProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        role: UserRole.cliente,
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<List<AccountProfile>> listAccounts() async {
    try {
      final snapshot = await _col.get().timeout(_timeout);
      final accounts = <AccountProfile>[];
      for (final doc in snapshot.docs) {
        final uid = InputSanitizer.uid(doc.id);
        final role = UserRole.parse(doc.data()['role'] as String?);
        if (uid == null || role == null) continue;
        accounts.add(
          AccountProfile(
            uid: uid,
            email: InputSanitizer.email(doc.data()['email'] as String?),
            displayName: InputSanitizer.displayName(
              doc.data()['displayName'] as String?,
            ),
            role: role,
          ),
        );
      }
      accounts.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
      return accounts;
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> assignRole({
    required String uid,
    required UserRole role,
  }) async {
    final safeUid = InputSanitizer.uid(uid);
    if (safeUid == null) {
      throw const RoleException('Cuenta inválida.');
    }
    try {
      await _col.doc(safeUid).update({
        'role': role.storageValue,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(_timeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  RoleException _map(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const RoleException(
          'Firebase no dejó leer tu cuenta. Publica firestore.rules.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return const RoleException('Sin señal para confirmar tu cuenta.');
      default:
        return RoleException('No se pudo leer tu cuenta (${error.code}).');
    }
  }
}
