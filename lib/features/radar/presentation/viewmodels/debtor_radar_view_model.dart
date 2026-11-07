import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/radar/data/radar_mute_store.dart';
import 'package:dale_u/features/radar/domain/debtor_hit.dart';
import 'package:dale_u/features/radar/domain/debtor_radar.dart';
import 'package:flutter/foundation.dart';

/// Radar local. No escribe en Firestore.
class DebtorRadarViewModel extends ChangeNotifier {
  DebtorRadarViewModel({required this.store}) {
    _muted = store.read();
  }

  final RadarMuteStore store;

  var _muted = <String>{};
  var _inside = <String>{};
  DebtorHit? _pending;

  DebtorHit? get pending => _pending;

  bool isMuted(String clientId) => _muted.contains(clientId);

  Future<void> setMuted({required String clientId, required bool muted}) async {
    await store.setMuted(clientId: clientId, muted: muted);
    _muted = store.read();
    if (muted) {
      _inside.remove(clientId);
      if (_pending?.clientId == clientId) _pending = null;
    }
    notifyListeners();
  }

  void dismiss() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  void scan({
    required bool onRoute,
    required GeoFix? here,
    required List<Client> clients,
    required Map<String, int> balances,
  }) {
    if (!onRoute || here == null) {
      final had = _pending != null || _inside.isNotEmpty;
      _inside = {};
      _pending = null;
      if (had) notifyListeners();
      return;
    }

    _inside = DebtorRadar.stillInside(
      here: here,
      clients: clients,
      previouslyInside: _inside,
    );
    if (_pending != null) return;

    final hit = DebtorRadar.entering(
      here: here,
      clients: clients,
      balances: balances,
      mutedIds: _muted,
      alreadyInside: _inside,
    );
    if (hit == null) return;
    _inside = {..._inside, hit.clientId};
    _pending = hit;
    notifyListeners();
  }
}
