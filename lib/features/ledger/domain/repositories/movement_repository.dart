import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';

abstract class MovementRepository {
  Future<Movement> record(Movement movement);

  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  });

  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  });

  Future<void> voidById({
    required String vendorUid,
    required String id,
  });

  /// Saldo por cliente: fiados menos pagos. Puede ser negativo (a favor).
  Future<Map<String, int>> balancesByVendor(String vendorUid);

  /// Fiados y pagos de un rango [start, end), sin anulados.
  Future<List<Movement>> listByDay({
    required String vendorUid,
    required DateTime start,
    required DateTime end,
  });

  /// Sube pendientes y baja remotos. No borra lo local si falla.
  Future<void> syncPending(String vendorUid);
}
