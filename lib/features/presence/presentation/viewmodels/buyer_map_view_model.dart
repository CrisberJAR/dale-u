import 'dart:async';

import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:flutter/foundation.dart';

/// Nombre público del vendedor. Vacío si aún no lo publicó.
typedef VendorNameLookup = Future<String> Function(String vendorUid);

/// Muestra a todos los panaderos en ruta. Cualquiera con sesión puede ver la
/// ruta, deba o no. Lee solo mientras el mapa está abierto: sin listener 24/7.
class BuyerMapViewModel extends ChangeNotifier {
  BuyerMapViewModel({required this.remote, this.nameOf, this.now});

  final PresenceRemoteDataSource remote;
  final VendorNameLookup? nameOf;
  final DateTime Function()? now;

  StreamSubscription<List<VendorOnRoute>>? _sub;
  final _latest = <String, VendorOnMap>{};
  final _names = <String, String>{};
  bool _loading = false;
  bool _disposed = false;
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

  /// [known] son los vendedores con los que ya tiene cuenta: sus nombres
  /// salen gratis. Al resto se le pregunta una vez su nombre público.
  Future<void> start(List<LinkedAccount> known) async {
    await stop();
    for (final account in known) {
      if (account.vendorName.isNotEmpty) {
        _names[account.vendorUid] = account.vendorName;
      }
    }
    _loading = true;
    _errorMessage = null;
    _notify();

    final first = Completer<void>();
    _sub = remote.watchAllOnRoute().listen(
      (vendors) async {
        await _put(vendors);
        if (!first.isCompleted) first.complete();
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Buyer map watch failed: ${error.runtimeType}');
        debugPrint('$stack');
        _errorMessage = 'Sin señal para ver al panadero.';
        if (!first.isCompleted) first.complete();
        _notify();
      },
    );
    await first.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _errorMessage ??= 'Sin señal para ver al panadero.';
      },
    );
    _loading = false;
    _notify();
  }

  Future<void> _put(List<VendorOnRoute> vendors) async {
    final next = <String, VendorOnMap>{};
    for (final vendor in vendors) {
      next[vendor.vendorUid] = VendorOnMap(
        vendorUid: vendor.vendorUid,
        name: await _nameFor(vendor.vendorUid),
        presence: vendor.presence,
      );
    }
    _latest
      ..clear()
      ..addAll(next);
    _errorMessage = null;
    _notify();
  }

  Future<String> _nameFor(String vendorUid) async {
    final cached = _names[vendorUid];
    if (cached != null) return cached;
    var name = '';
    final lookup = nameOf;
    if (lookup != null) {
      try {
        name = await lookup(vendorUid);
      } catch (error) {
        debugPrint('Vendor name lookup failed: ${error.runtimeType}');
      }
    }
    final label = name.isEmpty ? 'Panadero' : name;
    _names[vendorUid] = label;
    return label;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _latest.clear();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
