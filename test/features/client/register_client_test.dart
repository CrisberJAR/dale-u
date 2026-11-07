import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';
import 'package:dale_u/features/client/domain/usecases/register_client.dart';
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
    last = Client(
      id: id,
      vendorUid: vendorUid,
      name: name,
      phone: phone,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
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
  test('registra cliente sanitizado de forma local', () async {
    final repo = _MemoryClientRepository();
    final useCase = RegisterClient(repo);

    final client = await useCase(
      vendorUid: 'uid123',
      rawName: '  Doña María\n  ',
      rawPhone: 'abc300-123-4567',
    );

    expect(client.name, 'Doña María');
    expect(client.phone, '300-123-4567');
    expect(client.pendingSync, isTrue);
  });

  test('rechaza nombre vacío', () async {
    final useCase = RegisterClient(_MemoryClientRepository());
    expect(
      () => useCase(vendorUid: 'uid123', rawName: ' ', rawPhone: ''),
      throwsA(isA<ClientException>()),
    );
  });

  test('edita nombre y teléfono sanitizados', () async {
    final repo = _MemoryClientRepository();
    await RegisterClient(repo)(
      vendorUid: 'uid123',
      rawName: 'María',
      rawPhone: '',
    );
    final updated = await UpdateClient(repo)(
      vendorUid: 'uid123',
      clientId: '1',
      rawName: '  Doña María  ',
      rawPhone: '3001234567',
    );
    expect(updated.name, 'Doña María');
    expect(updated.phone, '3001234567');
  });
}
