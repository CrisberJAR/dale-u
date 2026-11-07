import 'package:shared_preferences/shared_preferences.dart';

/// Recuerdo del interruptor y del último punto, para no escribir de más.
class PresenceLocalStore {
  PresenceLocalStore(this._preferences) : _memory = null;

  PresenceLocalStore.memory()
    : _preferences = null,
      _memory = <String, Object>{};

  final SharedPreferences? _preferences;
  final Map<String, Object>? _memory;

  static const _onRoute = 'daleu_presence_on_route';
  static const _lat = 'daleu_presence_lat';
  static const _lng = 'daleu_presence_lng';
  static const _at = 'daleu_presence_at';

  bool get onRoute => (_get(_onRoute) as bool?) ?? false;

  double? get lastLatitude => _get(_lat) as double?;

  double? get lastLongitude => _get(_lng) as double?;

  DateTime? get lastAt {
    final millis = _get(_at) as int?;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Object? _get(String key) => _memory?[key] ?? _readPrefs(key);

  Object? _readPrefs(String key) {
    final prefs = _preferences;
    if (prefs == null) return null;
    return prefs.get(key);
  }

  Future<void> _put(String key, Object value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    final prefs = _preferences!;
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  Future<void> setOnRoute(bool value) => _put(_onRoute, value);

  Future<void> rememberFix({
    required double latitude,
    required double longitude,
    required DateTime at,
  }) async {
    await _put(_lat, latitude);
    await _put(_lng, longitude);
    await _put(_at, at.millisecondsSinceEpoch);
  }

  Future<void> clearFix() async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(_lat);
      memory.remove(_lng);
      memory.remove(_at);
      return;
    }
    final prefs = _preferences;
    if (prefs == null) return;
    await prefs.remove(_lat);
    await prefs.remove(_lng);
    await prefs.remove(_at);
  }
}
