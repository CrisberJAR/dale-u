import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/presence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lima = GeoFix(latitude: -12.0464, longitude: -77.0428);
  // ~11 m al sur: no cuenta como avance.
  const nearby = GeoFix(latitude: -12.0465, longitude: -77.0428);
  // ~180 m al sur.
  const farther = GeoFix(latitude: -12.0480, longitude: -77.0428);
  final t0 = DateTime(2026, 8, 30, 10);

  test('el primer punto siempre se publica', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: null,
        lastAt: null,
        next: lima,
        now: t0,
      ),
      isTrue,
    );
  });

  test('antes de 10 segundos no escribe aunque se haya movido', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: t0,
        next: farther,
        now: t0.add(const Duration(seconds: 5)),
      ),
      isFalse,
    );
  });

  test('pasados 10 segundos y con avance de 15 m, sí escribe', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: t0,
        next: farther,
        now: t0.add(const Duration(seconds: 12)),
      ),
      isTrue,
    );
  });

  test('quieto no escribe hasta el latido', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: t0,
        next: nearby,
        now: t0.add(const Duration(minutes: 3)),
      ),
      isFalse,
    );
  });

  test('quieto, al llegar el latido escribe para seguir en el mapa', () {
    expect(
      PresencePolicy.shouldPublish(
        lastFix: lima,
        lastAt: t0,
        next: nearby,
        now: t0.add(PresencePolicy.heartbeat),
      ),
      isTrue,
    );
  });
}
