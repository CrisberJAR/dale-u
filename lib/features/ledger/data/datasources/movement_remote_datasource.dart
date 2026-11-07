import 'package:dale_u/features/ledger/domain/entities/movement.dart';

/// Lo que cambió en la nube desde un punto. [cursor] es la hora del
/// servidor del cambio más nuevo visto; `null` si no llegó nada.
final class MovementChanges {
  const MovementChanges({required this.movements, this.cursor});

  final List<Movement> movements;
  final DateTime? cursor;
}

abstract class MovementRemoteDataSource {
  Future<void> upsert(Movement movement);

  /// Varios de una vez (lotes de hasta 400). Si algo falla, falla todo el
  /// lote y quien llama reintenta uno por uno.
  Future<void> upsertAll(List<Movement> movements);

  Future<List<Movement>> fetchByClient({
    required String vendorUid,
    required String clientId,
  });

  /// Solo lo que cambió después de [since], de todos los clientes, en una
  /// sola consulta. Lanza [MovementDeltaUnavailable] si falta el índice.
  Future<MovementChanges> fetchChangedSince({
    required String vendorUid,
    required DateTime since,
  });
}

/// La consulta incremental no está lista (índice sin desplegar). Se usa la
/// descarga completa por cliente, que siempre funciona.
final class MovementDeltaUnavailable implements Exception {
  const MovementDeltaUnavailable();
}
