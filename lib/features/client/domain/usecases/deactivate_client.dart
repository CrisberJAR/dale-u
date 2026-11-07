import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class DeactivateClient {
  const DeactivateClient(this._repository);

  final ClientRepository _repository;

  Future<void> call({
    required String vendorUid,
    required String clientId,
  }) {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const ClientException('Sesión inválida. Vuelve a entrar.');
    }
    return _repository.deactivate(vendorUid: uid, id: id);
  }
}
