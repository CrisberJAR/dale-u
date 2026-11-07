import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';
import 'package:dale_u/features/client/domain/usecases/register_client.dart';
import 'package:dale_u/features/client/domain/usecases/set_client_house.dart';
import 'package:dale_u/features/client/domain/usecases/update_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryClientRepository implements ClientRepository {
  Client? last;

  @override
  Future<List<Client>> listByVendor(String vendorUid) async => [?last];

  @override
  Future<Client> register({
    required String vendorUid,
    required String name,
    required String phone,
  }) async {
    last = Client(
      id: '1',
      vendorUid: vendorUid,
      name: name,
      phone: phone,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    return last!;
  }

  @override
  Future<void> syncPending(String vendorUid) async {}

  @override
  Future<Client> updateDetails({
    required String vendorUid,
    required String id,
    required String name,
    required String phone,
  }) async {
    last = last!.copyWith(name: name, phone: phone);
    return last!;
  }

  @override
  Future<Client> updateHouse({
    required String vendorUid,
    required String id,
    required double? latitude,
    required double? longitude,
  }) async {
    last = last!.copyWith(latitude: latitude, longitude: longitude);
    return last!;
  }

  @override
  Future<void> deactivate({
    required String vendorUid,
    required String id,
  }) async {
    if (last?.id == id) last = last!.copyWith(active: false);
  }
}

void main() {
  test('guarda el pin de la casa y no borra el nombre', () async {
    final repo = _MemoryClientRepository();
    await RegisterClient(repo)(
      vendorUid: 'uid123',
      rawName: 'Doña María',
      rawPhone: '',
    );

    final marked = await SetClientHouse(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      latitude: -12.05,
      longitude: -77.04,
    );

    expect(marked.name, 'Doña María');
    expect(marked.hasHousePin, isTrue);
    expect(marked.latitude, -12.05);
    expect(marked.longitude, -77.04);
    expect(marked.pendingSync, isTrue);
  });

  test('editar el nombre no quita la casa', () async {
    final repo = _MemoryClientRepository();
    await RegisterClient(repo)(
      vendorUid: 'uid123',
      rawName: 'María',
      rawPhone: '',
    );
    await SetClientHouse(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      latitude: -12.05,
      longitude: -77.04,
    );
    final updated = await UpdateClient(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      rawName: 'Doña María',
      rawPhone: '',
    );
    expect(updated.name, 'Doña María');
    expect(updated.hasHousePin, isTrue);
  });

  test('quitar la marca deja al cliente sin pin', () async {
    final repo = _MemoryClientRepository();
    await RegisterClient(repo)(
      vendorUid: 'uid123',
      rawName: 'María',
      rawPhone: '',
    );
    await SetClientHouse(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      latitude: -12.05,
      longitude: -77.04,
    );
    final cleared = await SetClientHouse(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      latitude: null,
      longitude: null,
    );
    expect(cleared.hasHousePin, isFalse);
  });

  test('rechaza un punto fuera del mapa', () async {
    final repo = _MemoryClientRepository();
    await RegisterClient(repo)(
      vendorUid: 'uid123',
      rawName: 'María',
      rawPhone: '',
    );
    expect(
      () => SetClientHouse(repo)(
        vendorUid: 'uid123',
        clientId: '1',
        latitude: 99,
        longitude: -77,
      ),
      throwsA(isA<ClientException>()),
    );
  });
}
