import 'dart:async';

import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/error/sync_error_mapper.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/client/domain/client_roster.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/usecases/deactivate_client.dart';
import 'package:dale_u/features/client/domain/usecases/list_clients.dart';
import 'package:dale_u/features/client/domain/usecases/register_client.dart';
import 'package:dale_u/features/client/domain/usecases/set_client_house.dart';
import 'package:dale_u/features/client/domain/usecases/sync_clients.dart';
import 'package:dale_u/features/client/domain/usecases/update_client.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/ledger_spoken.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_balances.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_client_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/record_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/sync_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/update_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/void_movement.dart';
import 'package:dale_u/features/voice/domain/client_name_matcher.dart';
import 'package:flutter/foundation.dart';

class ClientViewModel extends ChangeNotifier {
  ClientViewModel({
    required ObserveAuthState observeAuthState,
    required this.listClients,
    required this.registerClient,
    required this.updateClientUseCase,
    required this.setClientHouseUseCase,
    required this.deactivateClientUseCase,
    required this.syncClients,
    required this.syncMovements,
    required this.recordMovement,
    required this.listBalances,
    required this.listClientMovements,
    required this.updateMovementUseCase,
    required this.voidMovementUseCase,
  }) {
    _authSubscription = observeAuthState().listen(_onAuthState);
  }

  final ListClients listClients;
  final RegisterClient registerClient;
  final UpdateClient updateClientUseCase;
  final SetClientHouse setClientHouseUseCase;
  final DeactivateClient deactivateClientUseCase;
  final SyncClients syncClients;
  final SyncMovements syncMovements;
  final RecordMovement recordMovement;
  final ListBalances listBalances;
  final ListClientMovements listClientMovements;
  final UpdateMovement updateMovementUseCase;
  final VoidMovement voidMovementUseCase;
  late final StreamSubscription<UserSession?> _authSubscription;

  String? _vendorUid;
  List<Client> _clients = const [];
  Map<String, int> _balances = const {};
  List<Movement> _openMovements = const [];
  String? _openClientId;
  bool _loading = false;
  bool _saving = false;
  String? _errorMessage;
  String? _syncError;
  String _searchQuery = '';
  ClientRosterFilter _rosterFilter = ClientRosterFilter.all;
  VoiceUndoable? _lastVoice;
  Timer? _undoTimer;

  /// Cuánto dura el botón Deshacer tras anotar por voz.
  static const undoWindow = Duration(seconds: 60);

  /// Lo último anotado por voz, mientras todavía se puede deshacer.
  VoiceUndoable? get undoableVoice => _lastVoice;

  List<Client> get clients => _clients;
  List<Client> get visibleClients => ClientRoster.apply(
    clients: _clients,
    balances: _balances,
    query: _searchQuery,
    filter: _rosterFilter,
  );
  String get searchQuery => _searchQuery;
  ClientRosterFilter get rosterFilter => _rosterFilter;
  List<Movement> get openMovements => _openMovements;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get errorMessage => _errorMessage;
  String? get syncError => _syncError;
  int get pendingSyncCount =>
      _clients.where((client) => client.pendingSync).length;

  Map<String, int> get balances => Map.unmodifiable(_balances);

  int balanceCents(String clientId) => _balances[clientId] ?? 0;

  int get debtorCount {
    return _clients.where((client) => balanceCents(client.id) > 0).length;
  }

  int get totalDebtCents {
    var total = 0;
    for (final client in _clients) {
      final balance = balanceCents(client.id);
      if (balance > 0) total += balance;
    }
    return total;
  }

  /// Sube cada vez que se busca por voz. La casa lo usa para abrir la lista.
  int get searchRequests => _searchRequests;
  int _searchRequests = 0;

  void setSearchQuery(String raw) {
    final next = InputSanitizer.spokenText(raw);
    if (next == _searchQuery) return;
    _searchQuery = next;
    notifyListeners();
  }

  void setRosterFilter(ClientRosterFilter filter) {
    if (filter == _rosterFilter) return;
    _rosterFilter = filter;
    notifyListeners();
  }

  /// Vuelve a mostrar la lista completa. No avisa: lo hace quien escribe.
  void _clearRoster() {
    _searchQuery = '';
    _rosterFilter = ClientRosterFilter.all;
  }

  /// Pone el texto en la barra y muestra coincidencias. Sin red.
  Future<({bool ok, String message})> applySearchByVoice({
    required String spokenQuery,
  }) async {
    final query = InputSanitizer.spokenText(spokenQuery);
    _searchQuery = query;
    _rosterFilter = ClientRosterFilter.all;
    _searchRequests++;
    notifyListeners();

    final count = visibleClients.length;
    if (query.isEmpty) {
      return (ok: true, message: 'Mostrando todos los clientes.');
    }
    if (count == 0) {
      return (ok: true, message: 'Ningún cliente coincide con $query.');
    }
    if (count == 1) {
      return (ok: true, message: 'Buscando $query. Hay 1 cliente.');
    }
    return (ok: true, message: 'Buscando $query. Hay $count clientes.');
  }

  Client? clientById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  Future<void> _onAuthState(UserSession? session) async {
    _vendorUid = InputSanitizer.uid(session?.uid);
    _errorMessage = null;
    if (_vendorUid == null) {
      _clients = const [];
      _balances = const {};
      _openMovements = const [];
      _openClientId = null;
      _searchQuery = '';
      _rosterFilter = ClientRosterFilter.all;
      notifyListeners();
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _vendorUid;
    if (uid == null) return;
    _loading = true;
    notifyListeners();
    try {
      _clients = await listClients(uid);
      _balances = await listBalances(uid);
      if (_openClientId != null) {
        _openMovements = await listClientMovements(
          vendorUid: uid,
          clientId: _openClientId!,
        );
      }
      _errorMessage = null;
      unawaited(_syncThenRefresh(uid));
    } catch (error, stack) {
      debugPrint('Client list failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudieron cargar los clientes.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadClientDetail(String clientId) async {
    final uid = _vendorUid;
    if (uid == null) return;
    _openClientId = clientId;
    _openMovements = await listClientMovements(
      vendorUid: uid,
      clientId: clientId,
    );
    notifyListeners();
  }

  Future<bool> addClient({required String name, required String phone}) {
    return _writeClient(() {
      return registerClient(vendorUid: _vendorUid!, rawName: name, rawPhone: phone);
    });
  }

  Future<bool> updateClient({
    required String id,
    required String name,
    required String phone,
  }) {
    return _writeClient(() {
      return updateClientUseCase(
        vendorUid: _vendorUid!,
        clientId: id,
        rawName: name,
        rawPhone: phone,
      );
    });
  }

  Future<bool> setHouseLocation({
    required String id,
    required double? latitude,
    required double? longitude,
  }) {
    return _writeClient(() {
      return setClientHouseUseCase(
        vendorUid: _vendorUid!,
        clientId: id,
        latitude: latitude,
        longitude: longitude,
      );
    });
  }

  Future<bool> deactivateClient(String id) {
    return _writeClient(() {
      return deactivateClientUseCase(vendorUid: _vendorUid!, clientId: id);
    });
  }

  Future<bool> _writeClient(Future<void> Function() action) async {
    final uid = _vendorUid;
    if (uid == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    if (_saving) return false;

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _clients = await listClients(uid);
      _balances = await listBalances(uid);
      // Si no, el buscador o el filtro anterior esconden lo recién guardado
      // y parece que no se guardó nada.
      _clearRoster();
      unawaited(_syncThenRefresh(uid));
      return true;
    } on ClientException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Client save failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo guardar el cliente.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> recordOpenMovement({
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) {
    final clientId = _openClientId;
    if (clientId == null) {
      _errorMessage = 'Abre la ficha del cliente otra vez.';
      notifyListeners();
      return Future.value(false);
    }
    return _writeLedger(() {
      return recordMovement(
        vendorUid: _vendorUid!,
        clientId: clientId,
        kind: kind,
        amountCents: amountCents,
        occurredAt: occurredAt,
      );
    });
  }

  Future<bool> updateOpenMovement({
    required String movementId,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) {
    return _writeLedger(() {
      return updateMovementUseCase(
        vendorUid: _vendorUid!,
        movementId: movementId,
        kind: kind,
        amountCents: amountCents,
        occurredAt: occurredAt,
      );
    });
  }

  Future<bool> voidOpenMovement(String movementId) {
    return _writeLedger(() {
      return voidMovementUseCase(
        vendorUid: _vendorUid!,
        movementId: movementId,
      );
    });
  }

  Future<bool> _writeLedger(Future<void> Function() action) async {
    final uid = _vendorUid;
    final clientId = _openClientId;
    if (uid == null) {
      _errorMessage = 'Sesión inválida. Vuelve a entrar.';
      notifyListeners();
      return false;
    }
    if (_saving) return false;

    _saving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _balances = await listBalances(uid);
      if (clientId != null) {
        _openMovements = await listClientMovements(
          vendorUid: uid,
          clientId: clientId,
        );
      }
      unawaited(_syncThenRefresh(uid));
      return true;
    } on LedgerException catch (error) {
      _errorMessage = error.userMessage;
      return false;
    } catch (error, stack) {
      debugPrint('Ledger update failed: ${error.runtimeType}');
      debugPrint('$stack');
      _errorMessage = 'No se pudo guardar el movimiento.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Anota fiado o pago en SQLite al instante. [ok] false = decir el mensaje como error.
  Future<({bool ok, String message})> recordLedgerByVoice({
    required MovementKind kind,
    required String spokenName,
    required int amountCents,
  }) async {
    final uid = _vendorUid;
    if (uid == null) {
      return (ok: false, message: 'Sesión inválida. Vuelve a entrar.');
    }
    if (_saving) {
      return (ok: false, message: 'Espera, estoy guardando.');
    }

    final match = ClientNameMatcher.match(_clients, spokenName);
    switch (match) {
      case ClientNameNone():
        return (
          ok: false,
          message:
              'No encuentro a $spokenName. Primero agrégala como cliente.',
        );
      case ClientNameAmbiguous(:final candidates):
        final names = candidates.take(3).map((client) => client.name).join(', ');
        return (
          ok: false,
          message: 'Hay varias: $names. Di el nombre completo.',
        );
      case ClientNameUnique(:final client):
        _saving = true;
        _errorMessage = null;
        notifyListeners();
        try {
          final movement = await recordMovement(
            vendorUid: uid,
            clientId: client.id,
            kind: kind,
            amountCents: amountCents,
          );
          _balances = await listBalances(uid);
          if (_openClientId == client.id) {
            _openMovements = await listClientMovements(
              vendorUid: uid,
              clientId: client.id,
            );
          }
          _clearRoster();
          _rememberVoice(
            VoiceUndoable(
              movementId: movement.id,
              clientName: client.name,
              kind: kind,
              amountCents: movement.amountCents,
            ),
          );
          unawaited(_syncThenRefresh(uid));
          final newBalance = balanceCents(client.id);
          return (
            ok: true,
            message: ledgerSpokenConfirmation(
              kind: kind,
              clientName: client.name,
              amountCents: movement.amountCents,
              newBalance: newBalance,
              at: movement.occurredAt,
            ),
          );
        } on LedgerException catch (error) {
          _errorMessage = error.userMessage;
          return (ok: false, message: error.userMessage);
        } catch (error, stack) {
          debugPrint('Ledger save failed: ${error.runtimeType}');
          debugPrint('$stack');
          const message = 'No se pudo guardar el movimiento.';
          _errorMessage = message;
          return (ok: false, message: message);
        } finally {
          _saving = false;
          notifyListeners();
        }
    }
  }

  void _rememberVoice(VoiceUndoable item) {
    _undoTimer?.cancel();
    _lastVoice = item;
    _undoTimer = Timer(undoWindow, () {
      _lastVoice = null;
      _undoTimer = null;
      notifyListeners();
    });
  }

  void _forgetVoice() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _lastVoice = null;
  }

  /// Anula lo último anotado por voz (por si se entendió mal).
  Future<({bool ok, String message})> undoLastVoiceMovement() async {
    final uid = _vendorUid;
    final last = _lastVoice;
    if (uid == null) {
      return (ok: false, message: 'Sesión inválida. Vuelve a entrar.');
    }
    if (last == null) {
      return (ok: false, message: 'No hay nada reciente para deshacer.');
    }
    if (_saving) {
      return (ok: false, message: 'Espera, estoy guardando.');
    }
    _saving = true;
    notifyListeners();
    try {
      await voidMovementUseCase(vendorUid: uid, movementId: last.movementId);
      _forgetVoice();
      _balances = await listBalances(uid);
      if (_openClientId != null) {
        _openMovements = await listClientMovements(
          vendorUid: uid,
          clientId: _openClientId!,
        );
      }
      unawaited(_syncThenRefresh(uid));
      return (ok: true, message: 'Listo. Anulé ${last.spokenLine}.');
    } on LedgerException catch (error) {
      return (ok: false, message: error.userMessage);
    } catch (error, stack) {
      debugPrint('Undo voice failed: ${error.runtimeType}');
      debugPrint('$stack');
      return (ok: false, message: 'No se pudo deshacer.');
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Consulta el saldo local. Sin red.
  Future<({bool ok, String message})> queryBalanceByVoice({
    required String spokenName,
  }) async {
    final uid = _vendorUid;
    if (uid == null) {
      return (ok: false, message: 'Sesión inválida. Vuelve a entrar.');
    }

    final match = ClientNameMatcher.match(_clients, spokenName);
    switch (match) {
      case ClientNameNone():
        return (
          ok: false,
          message:
              'No encuentro a $spokenName. Primero agrégala como cliente.',
        );
      case ClientNameAmbiguous(:final candidates):
        final names = candidates.take(3).map((client) => client.name).join(', ');
        return (
          ok: false,
          message: 'Hay varias: $names. Di el nombre completo.',
        );
      case ClientNameUnique(:final client):
        try {
          _balances = await listBalances(uid);
        } catch (error, stack) {
          debugPrint('Balance query failed: ${error.runtimeType}');
          debugPrint('$stack');
          return (ok: false, message: 'No se pudo consultar la deuda.');
        }
        return (
          ok: true,
          message: debtSpokenReply(
            clientName: client.name,
            balance: balanceCents(client.id),
          ),
        );
    }
  }

  /// Sube lo pendiente ahora (por ejemplo, antes de mandar el enlace del
  /// estado de cuenta). Si no hay señal, no pasa nada: queda en el teléfono.
  Future<void> syncNow() async {
    final uid = _vendorUid;
    if (uid == null) return;
    await _syncThenRefresh(uid);
  }

  Future<void> _syncThenRefresh(String uid) async {
    try {
      await syncClients(uid);
      await syncMovements(uid);
      _syncError = null;
    } catch (error, stack) {
      debugPrint('Client sync failed: ${error.runtimeType}');
      debugPrint('$stack');
      _syncError = syncErrorMessage(error);
    }
    if (_vendorUid != uid) return;
    try {
      _clients = await listClients(uid);
      _balances = await listBalances(uid);
      if (_openClientId != null) {
        _openMovements = await listClientMovements(
          vendorUid: uid,
          clientId: _openClientId!,
        );
      }
      notifyListeners();
    } catch (error, stack) {
      debugPrint('Client refresh after sync failed: ${error.runtimeType}');
      debugPrint('$stack');
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
}

/// Lo último anotado por voz, para el botón y el comando Deshacer.
final class VoiceUndoable {
  const VoiceUndoable({
    required this.movementId,
    required this.clientName,
    required this.kind,
    required this.amountCents,
  });

  final String movementId;
  final String clientName;
  final MovementKind kind;
  final int amountCents;

  /// "el fiado de S/ 10.00 a María"
  String get spokenLine {
    final what = kind == MovementKind.fiado ? 'el fiado' : 'el pago';
    final to = kind == MovementKind.fiado ? 'a' : 'de';
    return '$what de S/ ${formatSoles(amountCents)} $to $clientName';
  }
}
