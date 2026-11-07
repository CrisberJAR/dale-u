import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/voice/domain/client_name_matcher.dart';

/// Filtro rápido de la lista del vendedor.
enum ClientRosterFilter {
  all,
  withDebt,
  settled,
}

/// Filtra y ordena clientes en el teléfono. Sin red.
final class ClientRoster {
  const ClientRoster._();

  static List<Client> apply({
    required List<Client> clients,
    required Map<String, int> balances,
    required String query,
    required ClientRosterFilter filter,
  }) {
    final needle = ClientNameMatcher.fold(query);
    final filtered = clients.where((client) {
      if (needle.isNotEmpty) {
        if (!ClientNameMatcher.fold(client.name).contains(needle)) {
          return false;
        }
      }
      final balance = balances[client.id] ?? 0;
      return switch (filter) {
        ClientRosterFilter.all => true,
        ClientRosterFilter.withDebt => balance > 0,
        // Cero o a favor: no debe. Quedan en "Al día".
        ClientRosterFilter.settled => balance <= 0,
      };
    }).toList();

    filtered.sort((a, b) {
      final debtA = _debtRank(balances[a.id] ?? 0);
      final debtB = _debtRank(balances[b.id] ?? 0);
      if (debtA != debtB) return debtB.compareTo(debtA);

      final activity = _activity(b).compareTo(_activity(a));
      if (activity != 0) return activity;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return filtered;
  }

  static int _debtRank(int balance) => balance > 0 ? balance : 0;

  static DateTime _activity(Client client) {
    return client.updatedAt.isAfter(client.createdAt)
        ? client.updatedAt
        : client.createdAt;
  }
}
