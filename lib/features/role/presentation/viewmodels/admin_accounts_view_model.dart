import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/usecases/assign_role.dart';
import 'package:dale_u/features/role/domain/usecases/list_accounts.dart';
import 'package:flutter/foundation.dart';

/// Panel del administrador: ve las cuentas y decide quién vende.
class AdminAccountsViewModel extends ChangeNotifier {
  AdminAccountsViewModel({
    required this.listAccounts,
    required this.assignRole,
  });

  final ListAccounts listAccounts;
  final AssignRole assignRole;

  List<AccountProfile> _accounts = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _query = '';
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String get query => _query;

  List<AccountProfile> get visibleAccounts {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _accounts;
    return _accounts
        .where(
          (account) =>
              account.displayName.toLowerCase().contains(needle) ||
              account.email.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  void setQuery(String raw) {
    final next = raw.trim();
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _accounts = await listAccounts();
    } catch (error, stack) {
      debugPrint('Accounts list failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = error is RoleException
          ? error.userMessage
          : 'No se pudieron leer las cuentas.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<({bool ok, String message})> changeRole({
    required AccountProfile account,
    required UserRole role,
  }) async {
    if (_isSaving) {
      return (ok: false, message: 'Espera, se está guardando.');
    }
    if (account.role == role) {
      return (ok: true, message: '${account.displayName} ya es ${role.label}.');
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    var message = '${account.displayName} ahora es ${role.label}.';
    var ok = true;
    try {
      await assignRole(uid: account.uid, role: role);
      _accounts = _accounts
          .map((item) => item.uid == account.uid ? item.copyWith(role: role) : item)
          .toList(growable: false);
    } catch (error, stack) {
      debugPrint('Assign role failed: ${error.runtimeType}');
      debugPrint('$stack');
      ok = false;
      message = error is RoleException
          ? error.userMessage
          : 'No se pudo cambiar el rol.';
      _errorMessage = message;
    }
    _isSaving = false;
    notifyListeners();
    return (ok: ok, message: message);
  }
}
