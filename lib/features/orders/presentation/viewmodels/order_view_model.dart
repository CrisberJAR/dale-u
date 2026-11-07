import 'dart:async';

import 'package:dale_u/core/error/order_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/orders/data/pan_order_local_datasource.dart';
import 'package:dale_u/features/orders/domain/entities/pan_order.dart';
import 'package:flutter/foundation.dart';

class OrderViewModel extends ChangeNotifier {
  OrderViewModel({
    required ObserveAuthState observeAuthState,
    required PanOrderLocalDataSource this._local,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  /// Para tests de pantallas que no anotan pedidos.
  OrderViewModel.idle() : _local = null;

  final PanOrderLocalDataSource? _local;
  StreamSubscription<UserSession?>? _authSubscription;

  String? _vendorUid;
  List<PanOrder> _orders = const [];
  bool _saving = false;
  String? _errorMessage;

  List<PanOrder> get pending => _orders;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;

  Future<void> _onAuth(UserSession? session) async {
    _vendorUid = InputSanitizer.uid(session?.uid);
    _errorMessage = null;
    if (_vendorUid == null) {
      _orders = const [];
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _vendorUid;
    final local = _local;
    if (uid == null || local == null) return;
    try {
      _orders = await local.listPending(uid);
      _errorMessage = null;
    } catch (error, stack) {
      debugPrint('Order list failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudieron cargar los pedidos.';
    }
    notifyListeners();
  }

  Future<bool> add({
    required String label,
    required int deliveryDateKey,
  }) async {
    final uid = _vendorUid;
    final local = _local;
    if (uid == null || local == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    if (_saving) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await local.insert(
        vendorUid: uid,
        label: label,
        deliveryDateKey: deliveryDateKey,
      );
      _orders = await local.listPending(uid);
      return true;
    } on OrderException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Order save failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo guardar el pedido.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> complete(String id) async {
    final uid = _vendorUid;
    final local = _local;
    if (uid == null || local == null) return;
    try {
      await local.complete(vendorUid: uid, id: id);
      _orders = await local.listPending(uid);
      _errorMessage = null;
    } on OrderException catch (error) {
      _errorMessage = error.userMessage;
    } catch (error, stack) {
      debugPrint('Order complete failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo marcar el pedido.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
