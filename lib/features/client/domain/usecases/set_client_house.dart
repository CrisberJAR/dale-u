import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

/// Guarda o quita el pin de la casa. Local primero.
class SetClientHouse {
  const SetClientHouse(this._repository);

  final ClientRepository _repository;

  Future<Client> call({
    required String vendorUid,
    required String clientId,
    required double? latitude,
    required double? longitude,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const ClientException('Sesión inválida. Vuelve a entrar.');
    }
    if (latitude == null && longitude == null) {
      return _repository.updateHouse(
        vendorUid: uid,
        id: id,
        latitude: null,
        longitude: null,
      );
    }
    final lat = InputSanitizer.latitude(latitude);
    final lng = InputSanitizer.longitude(longitude);
    if (lat == null || lng == null) {
      throw const ClientException('Ese punto no es una ubicación válida.');
    }
    return _repository.updateHouse(
      vendorUid: uid,
      id: id,
      latitude: lat,
      longitude: lng,
    );
  }
}
