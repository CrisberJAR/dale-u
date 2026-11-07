import 'package:dale_u/core/theme/look_kind.dart';
import 'package:dale_u/core/theme/look_store.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/foundation.dart';

/// Cambia la piel y la deja guardada. No toca fiados ni roles.
class LookViewModel extends ChangeNotifier {
  LookViewModel({required LookStore store})
    : _store = store,
      kind = store.read() {
    VendorLook.apply(kind);
  }

  final LookStore _store;
  LookKind kind;

  bool get isBakery => kind == LookKind.bakery;

  String get switchLabel {
    return isBakery ? 'Volver al diseño original' : 'Usar diseño cálido';
  }

  Future<void> toggle() async {
    kind = isBakery ? LookKind.classic : LookKind.bakery;
    VendorLook.apply(kind);
    notifyListeners();
    await _store.save(kind);
  }
}
