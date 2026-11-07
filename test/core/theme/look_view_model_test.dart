import 'package:dale_u/core/theme/look_kind.dart';
import 'package:dale_u/core/theme/look_store.dart';
import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/core/theme/vendor_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => VendorLook.apply(LookKind.bakery));

  test('sin dato guardado nace en el look cálido', () {
    final store = LookStore.memory();
    final look = LookViewModel(store: store);

    expect(look.kind, LookKind.bakery);
    expect(VendorLook.accent, const Color(0xFF4A2C11));

    look.dispose();
  });

  test('vuelve al original y lo recuerda', () async {
    final store = LookStore.memory();
    final look = LookViewModel(store: store);

    await look.toggle();

    expect(look.kind, LookKind.classic);
    expect(VendorLook.accent, const Color(0xFF111111));
    expect(store.read(), LookKind.classic);

    final again = LookViewModel(store: store);
    expect(again.kind, LookKind.classic);
    expect(VendorLook.ink, const Color(0xFF111111));

    look.dispose();
    again.dispose();
  });
}
