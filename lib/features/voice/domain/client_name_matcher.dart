import 'package:dale_u/features/client/domain/entities/client.dart';

sealed class ClientNameMatch {
  const ClientNameMatch();
}

final class ClientNameNone extends ClientNameMatch {
  const ClientNameNone();
}

final class ClientNameAmbiguous extends ClientNameMatch {
  const ClientNameAmbiguous(this.candidates);
  final List<Client> candidates;
}

final class ClientNameUnique extends ClientNameMatch {
  const ClientNameUnique(this.client);
  final Client client;
}

/// Empareja un nombre dictado con la lista local. Sin red.
final class ClientNameMatcher {
  const ClientNameMatcher._();

  static ClientNameMatch match(List<Client> clients, String spokenName) {
    final needle = fold(spokenName);
    if (needle.length < 2) return const ClientNameNone();

    final exact = clients.where((client) => fold(client.name) == needle).toList();
    if (exact.length == 1) return ClientNameUnique(exact.first);
    if (exact.length > 1) return ClientNameAmbiguous(exact);

    final partial = clients.where((client) {
      final name = fold(client.name);
      return name.contains(needle) || needle.contains(name);
    }).toList();

    if (partial.length == 1) return ClientNameUnique(partial.first);
    if (partial.length > 1) return ClientNameAmbiguous(partial);
    return const ClientNameNone();
  }

  static String fold(String raw) {
    final lower = raw.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
    return lower
        .replaceAll(RegExp(r'[^a-z0-9ñ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
