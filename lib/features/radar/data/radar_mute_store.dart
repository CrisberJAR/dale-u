import 'package:shared_preferences/shared_preferences.dart';

/// Casas silenciadas. Solo en el teléfono.
class RadarMuteStore {
  RadarMuteStore(this._preferences) : _memory = null;

  RadarMuteStore.memory()
    : _preferences = null,
      _memory = <String>{};

  final SharedPreferences? _preferences;
  final Set<String>? _memory;

  static const _key = 'daleu_radar_muted';

  Set<String> read() {
    final memory = _memory;
    if (memory != null) return Set<String>.from(memory);
    final prefs = _preferences;
    if (prefs == null) return {};
    return {...prefs.getStringList(_key) ?? const <String>[]};
  }

  Future<void> setMuted({required String clientId, required bool muted}) async {
    final next = read();
    if (muted) {
      next.add(clientId);
    } else {
      next.remove(clientId);
    }
    final memory = _memory;
    if (memory != null) {
      memory
        ..clear()
        ..addAll(next);
      return;
    }
    await _preferences!.setStringList(_key, next.toList());
  }
}
