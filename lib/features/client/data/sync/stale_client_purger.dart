import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:dale_u/features/client/domain/inactive_client_policy.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/orders/data/pan_order_local_datasource.dart';
import 'package:flutter/foundation.dart';

/// Desactivado + al día + 1 mes sin movimientos: primero nube, luego
/// teléfono. Con deuda pendiente no se toca.
class StaleClientPurger {
  StaleClientPurger({
    required this.clients,
    required this.movements,
    required this.orders,
    required this.remote,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final ClientLocalDataSource clients;
  final MovementLocalDataSource movements;
  final PanOrderLocalDataSource orders;
  final ClientRemoteDataSource remote;
  final DateTime Function() now;

  Future<int> run(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return 0;
    final inactive = await clients.listInactiveByVendor(uid);
    if (inactive.isEmpty) return 0;
    final balances = await movements.balancesByVendor(uid);
    var purged = 0;
    final at = now().toUtc();
    for (final client in inactive) {
      final lastMove = await movements.lastOccurredAt(
        vendorUid: uid,
        clientId: client.id,
      );
      if (!InactiveClientPolicy.shouldPurge(
        active: client.active,
        updatedAt: client.updatedAt,
        lastMovementAt: lastMove,
        now: at,
        balanceCents: balances[client.id] ?? 0,
      )) {
        continue;
      }
      try {
        await remote.deleteCascade(
          vendorUid: uid,
          clientId: client.id,
          inviteCode: client.inviteCode,
        );
        await movements.deleteByClient(vendorUid: uid, clientId: client.id);
        await orders.deleteByClient(vendorUid: uid, clientId: client.id);
        await clients.deleteById(vendorUid: uid, id: client.id);
        purged++;
      } catch (error, stack) {
        debugPrint('Purge client failed: ${error.runtimeType}');
        debugPrint('$stack');
      }
    }
    return purged;
  }
}
