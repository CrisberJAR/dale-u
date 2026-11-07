import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';

final class InviteLookup {
  const InviteLookup({
    required this.vendorUid,
    required this.clientId,
    required this.active,
    required this.linkedUid,
    this.vendorName = '',
  });

  final String vendorUid;
  final String clientId;
  final bool active;
  final String linkedUid;
  final String vendorName;
}

abstract class BuyerRemoteDataSource {
  Future<InviteLookup?> fetchInvite(String code);

  /// Toma el código y vincula la ficha en **una sola escritura atómica**:
  /// invitación, ficha, libreta y marcador. O queda todo o no queda nada.
  Future<void> claimAndLink({
    required String code,
    required String buyerUid,
    required LinkedAccount account,
  });

  Future<Client?> fetchClient({
    required String vendorUid,
    required String clientId,
  });

  /// Con [limit], solo los últimos (el saldo ya viene en la ficha).
  Future<List<Movement>> fetchMovements({
    required String vendorUid,
    required String clientId,
    int? limit,
  });

  /// Nombre público del vendedor. Vacío si aún no lo publicó.
  Future<String> fetchVendorName(String vendorUid);

  /// Libreta del comprador: un marcador por vendedor que lo tiene anotado.
  Future<List<LinkedAccount>> fetchLinks(String buyerUid);

  Future<void> saveLink({
    required String buyerUid,
    required LinkedAccount account,
  });

  Future<void> removeLink({
    required String buyerUid,
    required LinkedAccount account,
  });

  /// Deja el índice que las reglas usan para leer la presencia.
  Future<void> ensureVendorMarker({
    required String buyerUid,
    required LinkedAccount account,
  });
}
