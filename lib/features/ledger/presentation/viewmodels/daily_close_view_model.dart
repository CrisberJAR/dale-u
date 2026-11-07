import 'dart:async';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/ledger/domain/entities/daily_close.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_day_movements.dart';
import 'package:flutter/foundation.dart';

class DailyCloseViewModel extends ChangeNotifier {
  DailyCloseViewModel({
    required ObserveAuthState observeAuthState,
    required ListDayMovements this.listDayMovements,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  DailyCloseViewModel.idle() : listDayMovements = null;

  final ListDayMovements? listDayMovements;
  StreamSubscription<UserSession?>? _authSubscription;

  String? _vendorUid;
  int _dateKey = peruTodayDateKey();
  DailyClose _close = DailyClose.fromMovements(
    dateKey: peruTodayDateKey(),
    movements: const [],
  );
  bool _loading = false;
  String? _errorMessage;

  int get dateKey => _dateKey;
  DailyClose get close => _close;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> _onAuth(UserSession? session) async {
    _vendorUid = InputSanitizer.uid(session?.uid);
    _errorMessage = null;
    if (_vendorUid == null) {
      _close = DailyClose.fromMovements(dateKey: _dateKey, movements: const []);
      notifyListeners();
      return;
    }
    await load(_dateKey);
  }

  Future<void> load(int dateKey) async {
    final uid = _vendorUid;
    final useCase = listDayMovements;
    if (uid == null || useCase == null) return;
    if (!isValidPeruDateKey(dateKey)) return;
    _dateKey = dateKey;
    _loading = true;
    notifyListeners();
    try {
      _close = await useCase(vendorUid: uid, dateKey: dateKey);
      _errorMessage = null;
    } catch (error, stack) {
      debugPrint('Daily close failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo cargar el cuadre del día.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(_dateKey);

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
