import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/radar/data/radar_mute_store.dart';
import 'package:dale_u/features/radar/domain/debtor_radar.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

Client _client({
  required String id,
  required String name,
  double? latitude,
  double? longitude,
}) {
  return Client(
    id: id,
    vendorUid: 'uid123',
    name: name,
    phone: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  const house = GeoFix(latitude: -12.0464, longitude: -77.0428);
  const close = GeoFix(latitude: -12.0470, longitude: -77.0428);
  const far = GeoFix(latitude: -12.0495, longitude: -77.0428);

  final maria = _client(
    id: 'c1',
    name: 'María',
    latitude: house.latitude,
    longitude: house.longitude,
  );

  test('avisa si hay casa, deuda y está cerca', () {
    expect(close.metersTo(house), lessThan(150));
    final hit = DebtorRadar.entering(
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
      mutedIds: const {},
      alreadyInside: const {},
    );
    expect(hit, isNotNull);
    expect(hit!.name, 'María');
    expect(hit.balanceCents, 5000);
  });

  test('sin pin de casa no avisa', () {
    final hit = DebtorRadar.entering(
      here: close,
      clients: [_client(id: 'c1', name: 'María')],
      balances: const {'c1': 5000},
      mutedIds: const {},
      alreadyInside: const {},
    );
    expect(hit, isNull);
  });

  test('sin deuda no avisa', () {
    final hit = DebtorRadar.entering(
      here: close,
      clients: [maria],
      balances: const {'c1': 0},
      mutedIds: const {},
      alreadyInside: const {},
    );
    expect(hit, isNull);
  });

  test('silenciado no avisa', () {
    final hit = DebtorRadar.entering(
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
      mutedIds: const {'c1'},
      alreadyInside: const {},
    );
    expect(hit, isNull);
  });

  test('lejos de la casa no avisa', () {
    expect(far.metersTo(house), greaterThan(150));
    final hit = DebtorRadar.entering(
      here: far,
      clients: [maria],
      balances: const {'c1': 5000},
      mutedIds: const {},
      alreadyInside: const {},
    );
    expect(hit, isNull);
  });

  test('si ya está adentro no vuelve a avisar', () {
    final hit = DebtorRadar.entering(
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
      mutedIds: const {},
      alreadyInside: const {'c1'},
    );
    expect(hit, isNull);
  });

  test('al alejarse sale del radio y puede volver a avisar', () {
    final still = DebtorRadar.stillInside(
      here: far,
      clients: [maria],
      previouslyInside: {'c1'},
    );
    expect(still, isEmpty);
    expect(far.metersTo(house), greaterThan(220));
  });

  test('el más cercano gana si hay dos deudores', () {
    final fartherHouse = _client(
      id: 'c2',
      name: 'Juan',
      latitude: -12.0474,
      longitude: -77.0428,
    );
    final hit = DebtorRadar.entering(
      here: close,
      clients: [fartherHouse, maria],
      balances: const {'c1': 2000, 'c2': 9000},
      mutedIds: const {},
      alreadyInside: const {},
    );
    expect(hit?.name, 'Juan');
  });

  test('el view model avisa una vez y silenciar corta el aviso', () async {
    final radar = DebtorRadarViewModel(store: RadarMuteStore.memory());
    radar.scan(
      onRoute: true,
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
    );
    expect(radar.pending?.name, 'María');

    radar.scan(
      onRoute: true,
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
    );
    expect(radar.pending?.name, 'María');

    await radar.setMuted(clientId: 'c1', muted: true);
    expect(radar.pending, isNull);
    radar.scan(
      onRoute: true,
      here: close,
      clients: [maria],
      balances: const {'c1': 5000},
    );
    expect(radar.pending, isNull);
    radar.dispose();
  });
}
