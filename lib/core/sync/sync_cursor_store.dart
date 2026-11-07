import 'package:shared_preferences/shared_preferences.dart';

/// Hasta dónde llegó la última bajada incremental, por vendedor.
///
/// Una vez al día se baja todo de nuevo: cubre relojes desfasados y datos
/// viejos sin `updatedAt`.
class SyncCursorStore {
  SyncCursorStore(SharedPreferences preferences, {required this.scope})
    : _preferences = preferences;

  /// Pruebas: sin disco.
  SyncCursorStore.memory({required this.scope}) : _preferences = null;

  final SharedPreferences? _preferences;
  final String scope;
  final _memory = <String, int>{};

  static const fullPullEvery = Duration(hours: 24);

  String _cursorKey(String uid) => 'sync.$scope.$uid.cursor';
  String _fullKey(String uid) => 'sync.$scope.$uid.full';

  DateTime? cursor(String uid) => _read(_cursorKey(uid));

  bool fullPullDue(String uid, DateTime now) {
    final last = _read(_fullKey(uid));
    if (last == null) return true;
    final elapsed = now.difference(last);
    return elapsed.isNegative || elapsed >= fullPullEvery;
  }

  Future<void> saveCursor(String uid, DateTime at) =>
      _write(_cursorKey(uid), at);

  Future<void> saveFullPull(String uid, DateTime at) =>
      _write(_fullKey(uid), at);

  DateTime? _read(String key) {
    final millis = _preferences?.getInt(key) ?? _memory[key];
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> _write(String key, DateTime at) async {
    final millis = at.toUtc().millisecondsSinceEpoch;
    final preferences = _preferences;
    if (preferences == null) {
      _memory[key] = millis;
      return;
    }
    await preferences.setInt(key, millis);
  }
}
