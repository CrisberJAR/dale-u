import 'package:dale_u/core/theme/look_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El look se recuerda en el teléfono. No va a la nube.
class LookStore {
  LookStore(this._preferences) : _memory = null;

  LookStore.memory()
    : _preferences = null,
      _memory = <String, String>{};

  final SharedPreferences? _preferences;
  final Map<String, String>? _memory;

  static const _key = 'daleu_look';

  LookKind read() {
    final memory = _memory;
    if (memory != null) return LookKind.parse(memory[_key]);
    return LookKind.parse(_preferences?.getString(_key));
  }

  Future<void> save(LookKind kind) async {
    final memory = _memory;
    if (memory != null) {
      memory[_key] = kind.name;
      return;
    }
    await _preferences!.setString(_key, kind.name);
  }
}
