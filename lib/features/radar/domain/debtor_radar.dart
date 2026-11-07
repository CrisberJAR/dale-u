import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/radar/domain/debtor_hit.dart';
import 'package:dale_u/features/radar/domain/radar_policy.dart';

/// Quién entra o sale del radio. Todo en el teléfono.
final class DebtorRadar {
  const DebtorRadar._();

  /// El deudor más cercano que acaba de entrar. Null si no hay nadie nuevo.
  static DebtorHit? entering({
    required GeoFix here,
    required List<Client> clients,
    required Map<String, int> balances,
    required Set<String> mutedIds,
    required Set<String> alreadyInside,
  }) {
    DebtorHit? best;
    for (final client in clients) {
      if (!client.hasHousePin) continue;
      if (mutedIds.contains(client.id)) continue;
      if (alreadyInside.contains(client.id)) continue;
      final balance = balances[client.id] ?? 0;
      if (balance <= 0) continue;
      final meters = here.metersTo(
        GeoFix(latitude: client.latitude!, longitude: client.longitude!),
      );
      if (meters > RadarPolicy.approachMeters) continue;
      if (best == null || meters < best.meters) {
        best = DebtorHit(
          clientId: client.id,
          name: client.name,
          balanceCents: balance,
          meters: meters,
        );
      }
    }
    return best;
  }

  /// Siguen dentro si no se alejaron del radio de salida.
  static Set<String> stillInside({
    required GeoFix here,
    required List<Client> clients,
    required Set<String> previouslyInside,
  }) {
    if (previouslyInside.isEmpty) return const {};
    final next = <String>{};
    for (final client in clients) {
      if (!previouslyInside.contains(client.id) || !client.hasHousePin) {
        continue;
      }
      final meters = here.metersTo(
        GeoFix(latitude: client.latitude!, longitude: client.longitude!),
      );
      if (meters <= RadarPolicy.leaveMeters) {
        next.add(client.id);
      }
    }
    return next;
  }
}
