import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/presence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lima = GeoFix(latitude: -12.0464, longitude: -77.0428);
  const nearby = GeoFix(latitude: -12.0465, longitude: -77.0428);
  const farther = GeoFix(latitude: -12.0480, longitude: -77.0428);

  test('el primer punto siempre se publica', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: null,
        lastAt: null,
        next: lima,
        now: DateTime(2026, 8, 30, 10),
      ),
      isTrue,
    );
  });

  test('antes de cinco minutos no escribe aunque se haya movido', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: DateTime(2026, 8, 30, 10),
        next: farther,
        now: DateTime(2026, 8, 30, 10, 4),
      ),
      isFalse,
    );
  });

  test('a los cinco minutos, si no se movió, no escribe', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: DateTime(2026, 8, 30, 10),
        next: nearby,
        now: DateTime(2026, 8, 30, 10, 5),
      ),
      isFalse,
    );
  });

  test('a los cinco minutos y lejos, sí escribe', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: DateTime(2026, 8, 30, 10),
        next: farther,
        now: DateTime(2026, 8, 30, 10, 5),
      ),
      isTrue,
    );
  });
}
