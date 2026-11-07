import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/buyer_map_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Remote implements PresenceRemoteDataSource {
  _Remote(this.byVendor);

  final Map<String, VendorPresence?> byVendor;

  @override
  Future<void> publish(String vendorUid, VendorPresence presence) async {}

  @override
  Future<VendorPresence?> fetch(String vendorUid) async => byVendor[vendorUid];

  @override
  Stream<VendorPresence?> watch(String vendorUid) =>
      Stream<VendorPresence?>.value(byVendor[vendorUid]);

  @override
  Stream<List<VendorOnRoute>> watchAllOnRoute() {
    return Stream.value([
      for (final entry in byVendor.entries)
        if (entry.value != null && entry.value!.onRoute)
          VendorOnRoute(vendorUid: entry.key, presence: entry.value!),
    ]);
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 30, 20);
  const account = LinkedAccount(
    vendorUid: 'vend1',
    clientId: 'client1',
    vendorName: 'Don Pan',
  );

  test('solo muestra al vendedor que está en ruta con punto fresco', () async {
    final viewModel = BuyerMapViewModel(
      remote: _Remote({
        'vend1': VendorPresence(
          onRoute: true,
          updatedAt: now,
          fix: const GeoFix(latitude: -12.05, longitude: -77.04),
        ),
      }),
      now: () => now,
    );

    await viewModel.start([account]);
    expect(viewModel.visiblePins, hasLength(1));
    expect(viewModel.visiblePins.first.name, 'Don Pan');
    await viewModel.stop();
    viewModel.dispose();
  });

  test('si no está en ruta, el mapa queda sin pines', () async {
    final viewModel = BuyerMapViewModel(
      remote: _Remote({
        'vend1': VendorPresence(onRoute: false, updatedAt: now),
      }),
      now: () => now,
    );

    await viewModel.start([account]);
    expect(viewModel.visiblePins, isEmpty);
    await viewModel.stop();
    viewModel.dispose();
  });

  test('sin cuenta con el vendedor igual lo ve, con su nombre público',
      () async {
    final viewModel = BuyerMapViewModel(
      remote: _Remote({
        'otro': VendorPresence(
          onRoute: true,
          updatedAt: now,
          fix: const GeoFix(latitude: -12.06, longitude: -77.03),
        ),
      }),
      nameOf: (uid) async => uid == 'otro' ? 'Panadería Rosa' : '',
      now: () => now,
    );

    await viewModel.start(const []);
    expect(viewModel.visiblePins, hasLength(1));
    expect(viewModel.visiblePins.first.name, 'Panadería Rosa');
    await viewModel.stop();
    viewModel.dispose();
  });
}
