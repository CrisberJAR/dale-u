import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class RegisterClient {
  const RegisterClient(this._repository);

  final ClientRepository _repository;

  Future<Client> call({
    required String vendorUid,
    required String rawName,
    required String rawPhone,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) {
      throw const ClientException('Sesión inválida. Vuelve a entrar.');
    }
    final name = InputSanitizer.personName(rawName);
    if (name == null) {
      throw const ClientException('Escribe el nombre del cliente.');
    }
    final phone = InputSanitizer.phone(rawPhone);
    return _repository.register(vendorUid: uid, name: name, phone: phone);
  }
}
