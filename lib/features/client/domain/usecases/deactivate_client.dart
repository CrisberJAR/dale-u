import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';

/// Saldo local del cliente en céntimos (positivo = debe).
typedef ClientBalanceLookup =
    Future<int> Function({required String vendorUid, required String clientId});

/// Saca al cliente de la ruta. No se puede si todavía debe o tiene saldo a
/// favor: la deuda dejaría de verse en los totales.
class DeactivateClient {
  const DeactivateClient(this._repository, {this.balanceOf});

  final ClientRepository _repository;
  final ClientBalanceLookup? balanceOf;

  Future<void> call({
    required String vendorUid,
    required String clientId,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const ClientException('Sesión inválida. Vuelve a entrar.');
    }
    final lookup = balanceOf;
    if (lookup != null) {
      final balance = await lookup(vendorUid: uid, clientId: id);
      if (balance > 0) {
        throw ClientException(
          'Todavía debe S/ ${formatSoles(balance)}. '
          'Cobra o anula los fiados antes de desactivarlo.',
        );
      }
      if (balance < 0) {
        throw ClientException(
          'Tiene S/ ${formatSoles(-balance)} a favor. '
          'Devuélvelo o anótalo antes de desactivarlo.',
        );
      }
    }
    await _repository.deactivate(vendorUid: uid, id: id);
  }
}
