import 'package:dale_u/features/presence/domain/presence_policy.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 20);

  test('un punto fresco en ruta se ve en el mapa', () {
    final presence = VendorPresence.tryParse({
      'onRoute': true,
      'latitude': -12.05,
      'longitude': -77.04,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    expect(presence, isNotNull);
    expect(presence!.isVisibleAt(now), isTrue);
  });

  test('si ya no está en ruta, no se pinta', () {
    final presence = VendorPresence.tryParse({
      'onRoute': false,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    expect(presence!.isVisibleAt(now), isFalse);
  });

  test('un punto de hace más de 15 minutos no se pinta', () {
    final old = now.subtract(PresencePolicy.freshWindow + const Duration(minutes: 1));
    final presence = VendorPresence.tryParse({
      'onRoute': true,
      'latitude': -12.05,
      'longitude': -77.04,
      'updatedAt': old.millisecondsSinceEpoch,
    });
    expect(presence!.isVisibleAt(now), isFalse);
  });
}
