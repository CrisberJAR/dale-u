import 'package:dale_u/features/ledger/domain/entities/movement.dart';

abstract class MovementRemoteDataSource {
  Future<void> upsert(Movement movement);

  Future<List<Movement>> fetchByClient({
    required String vendorUid,
    required String clientId,
  });
}
