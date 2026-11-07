import 'package:dale_u/features/inbox/domain/pan_request.dart';

abstract class PanInboxRemote {
  Future<void> send({
    required String vendorUid,
    required String buyerUid,
    required String clientId,
    required String clientName,
  });

  Stream<List<PanRequest>> watch(String vendorUid);

  /// Entregado: se borra el recado. No se archiva.
  Future<void> markSeen({
    required String vendorUid,
    required String buyerUid,
  });
}
