import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class UpdateClient {
  const UpdateClient(this._repository);

  final ClientRepository _repository;

  Future<Client> call({
    required String vendorUid,
    required String clientId,
    required String rawName,
    required String rawPhone,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const ClientException('Sesión inválida. Vuelve a entrar.');
    }
    final name = InputSanitizer.personName(rawName);
    if (name == null) {
      throw const ClientException('Escribe el nombre del cliente.');
    }
    final phone = InputSanitizer.phone(rawPhone);
    return _repository.updateDetails(
      vendorUid: uid,
      id: id,
      name: name,
      phone: phone,
    );
  }
}
