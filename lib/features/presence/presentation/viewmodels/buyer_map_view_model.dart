import 'dart:async';

import 'package:dale_u/core/error/presence_exception.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:flutter/foundation.dart';

/// Lee la presencia solo mientras el mapa está abierto. Sin listener 24/7.
class BuyerMapViewModel extends ChangeNotifier {
  BuyerMapViewModel({required this.remote, this.now});

  final PresenceRemoteDataSource remote;
  final DateTime Function()? now;

  final _subs = <StreamSubscription<VendorPresence?>>[];
  final _latest = <String, VendorOnMap>{};
  bool _loading = false;
  String? _errorMessage;

  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  List<VendorOnMap> get visiblePins {
    final stamp = now?.call() ?? DateTime.now();
    return _latest.values
        .where((item) => item.presence.isVisibleAt(stamp))
        .toList();
  }

  bool get anyOnRoute => visiblePins.isNotEmpty;

  Future<void> start(List<LinkedAccount> accounts) async {
    await stop();
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    if (accounts.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }

    for (final account in accounts) {
      try {
        final first = await remote.fetch(account.vendorUid);
        _put(account, first);
      } on PresenceException catch (error) {
        _errorMessage = error.userMessage;
      } catch (error, stack) {
        debugPrint('Buyer map fetch failed: ${error.runtimeType}');
        debugPrint('$stack');
        _errorMessage = 'Sin señal para ver al panadero.';
      }
    }
    _loading = false;
    notifyListeners();

    for (final account in accounts) {
      _subs.add(
        remote.watch(account.vendorUid).listen(
          (presence) => _put(account, presence),
          onError: (Object error, StackTrace stack) {
            debugPrint('Buyer map watch failed: ${error.runtimeType}');
            debugPrint('$stack');
          },
        ),
      );
    }
  }

  void _put(LinkedAccount account, VendorPresence? presence) {
    if (presence == null) {
      _latest.remove(account.vendorUid);
    } else {
      _latest[account.vendorUid] = VendorOnMap(
        vendorUid: account.vendorUid,
        name: account.vendorName.isEmpty ? 'Tu vendedor' : account.vendorName,
        presence: presence,
      );
    }
    notifyListeners();
  }

  Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _latest.clear();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
