import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

class ListClients {
  const ListClients(this._repository);

  final ClientRepository _repository;

  Future<List<Client>> call(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return const [];
    return _repository.listByVendor(uid);
  }
}
