import 'dart:async';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/buyer/data/buyer_remote_datasource.dart';
import 'package:dale_u/features/buyer/data/linked_account_store.dart';
import 'package:dale_u/features/buyer/domain/buyer_exception.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/invite_code.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:flutter/foundation.dart';

/// La deuda del comprador con un vendedor concreto.
final class BuyerLedger {
  const BuyerLedger({
    required this.account,
    required this.client,
    required this.movements,
  });

  final LinkedAccount account;
  final Client client;
  final List<Movement> movements;

  String get vendorLabel {
    return account.vendorName.isEmpty ? 'Tu vendedor' : account.vendorName;
  }

  int get balanceCents {
    var total = 0;
    for (final movement in movements) {
      total += movement.signedCents;
    }
    return total;
  }
}

class BuyerViewModel extends ChangeNotifier {
  BuyerViewModel({
    required ObserveAuthState observeAuthState,
    required this.store,
    required this.remote,
    required this.inbox,
  }) {
    _authSubscription = observeAuthState().listen(_onAuth);
  }

  final LinkedAccountStore store;
  final BuyerRemoteDataSource remote;
  final PanInboxRemote inbox;
  late final StreamSubscription<UserSession?> _authSubscription;

  String? _buyerUid;
  List<BuyerLedger> _ledgers = const [];
  bool _loading = false;
  bool _saving = false;
  String? _sendingAccountId;
  String? _errorMessage;
  String? _panStatus;

  List<BuyerLedger> get ledgers => _ledgers;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  String? get panStatus => _panStatus;
  bool get isLinked => _ledgers.isNotEmpty;

  bool sendingPan(String accountId) => _sendingAccountId == accountId;

  /// Lo que debe en total, sumando a todos sus vendedores.
  int get totalbalanceCents {
    var total = 0;
    for (final ledger in _ledgers) {
      total += ledger.balanceCents;
    }
    return total;
  }

  Future<void> _onAuth(UserSession? session) async {
    _buyerUid = InputSanitizer.uid(session?.uid);
    _errorMessage = null;
    if (_buyerUid == null) {
      _ledgers = const [];
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _buyerUid;
    if (uid == null) return;
    _loading = true;
    notifyListeners();
    try {
      final links = await _readLinks(uid);
      if (links.isEmpty) {
        _ledgers = const [];
        _errorMessage = null;
        return;
      }
      _errorMessage = null;
      _ledgers = await _loadAll(uid, links);
    } on BuyerException catch (error) {
      _errorMessage = error.userMessage;
    } catch (error, stack) {
      debugPrint('Buyer refresh failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo cargar tu cuenta.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> linkWithCode(String rawCode) async {
    final uid = _buyerUid;
    if (uid == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    final code = InviteCode.parse(rawCode);
    if (code == null) {
      _errorMessage = 'Escribe el código de 6 letras que te dio el vendedor.';
      notifyListeners();
      return false;
    }
    if (_saving) return false;
    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final invite = await remote.fetchInvite(code);
      if (invite == null) {
        throw const BuyerException('Ese código no existe.');
      }
      if (!invite.active) {
        throw const BuyerException('Ese código ya no está activo.');
      }
      if (invite.linkedUid.isNotEmpty && invite.linkedUid != uid) {
        throw const BuyerException('Este código ya está en uso.');
      }

      final account = LinkedAccount(
        vendorUid: invite.vendorUid,
        clientId: invite.clientId,
        vendorName: invite.vendorName,
      );
      if (_ledgers.any((ledger) => ledger.account.sameAs(account))) {
        throw const BuyerException('Ya estabas vinculado con ese vendedor.');
      }

      await remote.claimInvite(code: code, buyerUid: uid);
      await remote.linkClient(
        vendorUid: account.vendorUid,
        clientId: account.clientId,
        buyerUid: uid,
      );
      await remote.saveLink(buyerUid: uid, account: account);

      final accounts = [
        ..._ledgers.map((ledger) => ledger.account),
        account,
      ];
      _ledgers = await _loadAll(uid, accounts);
      return true;
    } on BuyerException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Buyer link failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo vincular. Inténtalo de nuevo.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// La nube manda; el teléfono solo responde cuando no hay señal.
  Future<List<LinkedAccount>> _readLinks(String uid) async {
    try {
      final remoteLinks = await remote.fetchLinks(uid);
      if (remoteLinks.isNotEmpty) return remoteLinks;
      // Puede ser una libreta vacía o una cuenta vinculada antes de la nube.
      final cached = await store.read(uid);
      if (cached.isEmpty) return const [];
      for (final account in cached) {
        await remote.saveLink(buyerUid: uid, account: account);
      }
      return cached;
    } on BuyerException {
      return store.read(uid);
    }
  }

  /// Carga cada deuda y descarta los marcadores que ya no valen.
  Future<List<BuyerLedger>> _loadAll(
    String uid,
    List<LinkedAccount> accounts,
  ) async {
    final ledgers = <BuyerLedger>[];
    final alive = <LinkedAccount>[];

    for (final account in accounts) {
      final client = await remote.fetchClient(
        vendorUid: account.vendorUid,
        clientId: account.clientId,
      );
      if (client == null || !client.active) {
        await _forget(uid, account);
        continue;
      }
      final movements = await remote.fetchMovements(
        vendorUid: account.vendorUid,
        clientId: account.clientId,
      );
      final named = await _withVendorName(uid, account);
      ledgers.add(
        BuyerLedger(account: named, client: client, movements: movements),
      );
      alive.add(named);
      await remote.ensureVendorMarker(buyerUid: uid, account: named);
    }

    ledgers.sort((a, b) => b.balanceCents.compareTo(a.balanceCents));
    await store.save(buyerUid: uid, accounts: alive);

    if (alive.length < accounts.length && ledgers.isEmpty) {
      _errorMessage = 'Esa cuenta ya no está activa. Pide un código nuevo.';
    }
    return ledgers;
  }

  Future<bool> requestPan(BuyerLedger ledger) async {
    final uid = _buyerUid;
    if (uid == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    if (_sendingAccountId != null) return false;
    _sendingAccountId = ledger.account.id;
    _errorMessage = null;
    _panStatus = null;
    notifyListeners();
    try {
      await inbox.send(
        vendorUid: ledger.account.vendorUid,
        buyerUid: uid,
        clientId: ledger.account.clientId,
        clientName: ledger.client.name,
      );
      _panStatus =
          'Se lo pediste a ${ledger.vendorLabel}. Lo verá al abrir la app.';
      return true;
    } on BuyerException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Pan request failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo pedir el pan. Inténtalo de nuevo.';
      return false;
    } finally {
      _sendingAccountId = null;
      notifyListeners();
    }
  }

  /// El vendedor publica su nombre en `vendors/{uid}`; ahí manda esa versión.
  /// Así se corrige solo cuando el vendedor lo cambia.
  Future<LinkedAccount> _withVendorName(
    String uid,
    LinkedAccount account,
  ) async {
    try {
      final name = await remote.fetchVendorName(account.vendorUid);
      if (name.isEmpty || name == account.vendorName) return account;
      final updated = account.copyWith(vendorName: name);
      await remote.saveLink(buyerUid: uid, account: updated);
      return updated;
    } catch (error) {
      debugPrint('Vendor name refresh failed: ${error.runtimeType}');
      return account;
    }
  }

  Future<void> _forget(String uid, LinkedAccount account) async {
    try {
      await remote.removeLink(buyerUid: uid, account: account);
    } catch (error) {
      debugPrint('Link cleanup failed: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}
