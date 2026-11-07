import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local inmediata (offline). Firestore llega en la 1.4.
class RoleLocalDataSource {
  RoleLocalDataSource(this._preferences);

  final SharedPreferences _preferences;

  static const _prefix = 'daleu_role_';

  Future<UserRole?> readRole(String uid) async {
    final key = _key(uid);
    if (key == null) return null;
    return UserRole.parse(_preferences.getString(key));
  }

  Future<void> saveRole({required String uid, required UserRole role}) async {
    final key = _key(uid);
    if (key == null) {
      throw StateError('UID inválido');
    }
    await _preferences.setString(key, role.storageValue);
  }

  Future<void> clearRole(String uid) async {
    final key = _key(uid);
    if (key == null) return;
    await _preferences.remove(key);
  }

  String? _key(String uid) {
    final safeUid = InputSanitizer.uid(uid);
    if (safeUid == null) return null;
    return '$_prefix$safeUid';
  }
}
