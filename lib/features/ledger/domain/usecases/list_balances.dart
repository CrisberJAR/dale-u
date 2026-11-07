import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class ListBalances {
  const ListBalances(this._repository);

  final MovementRepository _repository;

  Future<Map<String, int>> call(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return const {};
    return _repository.balancesByVendor(uid);
  }
}
