import 'package:dale_u/app/dale_u_app.dart';
import 'package:dale_u/features/presence/domain/vendor_on_map.dart';
import 'package:dale_u/core/error/auth_failure.dart';
import 'package:dale_u/core/error/result.dart';
import 'package:dale_u/core/theme/look_store.dart';
import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/features/auth/domain/entities/user_session.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_out.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/buyer/data/buyer_remote_datasource.dart';
import 'package:dale_u/features/buyer/data/linked_account_store.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/buyer/presentation/viewmodels/buyer_view_model.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/repositories/client_repository.dart';
import 'package:dale_u/features/client/domain/usecases/deactivate_client.dart';
import 'package:dale_u/features/client/domain/usecases/list_clients.dart';
import 'package:dale_u/features/client/domain/usecases/register_client.dart';
import 'package:dale_u/features/client/domain/usecases/set_client_house.dart';
import 'package:dale_u/features/client/domain/usecases/sync_clients.dart';
import 'package:dale_u/features/client/domain/usecases/update_client.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_balances.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_client_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/record_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/sync_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/update_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/void_movement.dart';
import 'package:dale_u/core/error/role_exception.dart';
import 'package:dale_u/features/role/domain/entities/account_profile.dart';
import 'package:dale_u/features/role/domain/entities/user_role.dart';
import 'package:dale_u/features/role/domain/repositories/role_repository.dart';
import 'package:dale_u/features/role/domain/usecases/assign_role.dart';
import 'package:dale_u/features/role/domain/usecases/list_accounts.dart';
import 'package:dale_u/features/role/domain/usecases/load_account.dart';
import 'package:dale_u/features/role/presentation/viewmodels/admin_accounts_view_model.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:dale_u/features/radar/data/radar_mute_store.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/data/presence_local_store.dart';
import 'package:dale_u/features/presence/domain/geo_fix.dart';
import 'package:dale_u/features/presence/domain/location_gateway.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/buyer_map_view_model.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:dale_u/features/voice/domain/voice_capture_gateway.dart';
import 'package:dale_u/features/voice/domain/voice_playback_gateway.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.session);

  final UserSession? session;

  @override
  Stream<UserSession?> observeAuthState() => Stream<UserSession?>.value(session);

  @override
  Future<Result<UserSession>> signInWithGoogle() async {
    return const Err(AuthFailure.unknown());
  }

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);
}

class _FakeRoleRepository implements RoleRepository {
  UserRole stored = UserRole.cliente;
  UserRole? cached;
  bool cloudFails = false;
  final accounts = <AccountProfile>[];
  final assigned = <String, UserRole>{};

  @override
  Future<UserRole?> cachedRole(String uid) async => cached;

  @override
  Future<AccountProfile> ensureAccount(UserSession session) async {
    if (cloudFails) {
      throw const RoleException('Sin señal para confirmar tu cuenta.');
    }
    return AccountProfile(
      uid: session.uid,
      email: session.email,
      displayName: session.displayName,
      role: stored,
    );
  }

  @override
  Future<List<AccountProfile>> listAccounts() async => accounts;

  @override
  Future<void> assignRole({
    required String uid,
    required UserRole role,
  }) async {
    assigned[uid] = role;
  }
}

class _FakeClientRepository implements ClientRepository {
  final List<Client> stored = [];

  @override
  Future<List<Client>> listByVendor(String vendorUid) async {
    return stored.where((client) => client.vendorUid == vendorUid).toList();
  }

  @override
  Future<Client> register({
    required String vendorUid,
    required String name,
    required String phone,
  }) async {
    final client = Client(
      id: 'c${stored.length}',
      vendorUid: vendorUid,
      name: name,
      phone: phone,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    stored.add(client);
    return client;
  }

  @override
  Future<void> syncPending(String vendorUid) async {}

  @override
  Future<Client> updateDetails({
    required String vendorUid,
    required String id,
    required String name,
    required String phone,
  }) async {
    final index = stored.indexWhere((client) => client.id == id);
    if (index < 0) {
      throw StateError('missing');
    }
    stored[index] = stored[index].copyWith(name: name, phone: phone);
    return stored[index];
  }

  @override
  Future<Client> updateHouse({
    required String vendorUid,
    required String id,
    required double? latitude,
    required double? longitude,
  }) async {
    final index = stored.indexWhere((client) => client.id == id);
    if (index < 0) {
      throw StateError('missing');
    }
    stored[index] = stored[index].copyWith(
      latitude: latitude,
      longitude: longitude,
    );
    return stored[index];
  }

  @override
  Future<void> deactivate({
    required String vendorUid,
    required String id,
  }) async {
    stored.removeWhere((client) => client.id == id);
  }
}

class _FakeMovementRepository implements MovementRepository {
  final items = <Movement>[];

  @override
  Future<Movement> record(Movement movement) async {
    items.add(movement);
    return movement;
  }

  @override
  Future<Map<String, int>> balancesByVendor(String vendorUid) async {
    final balances = <String, int>{};
    for (final item in items.where((m) => m.vendorUid == vendorUid)) {
      balances[item.clientId] = (balances[item.clientId] ?? 0) + item.signedCents;
    }
    return balances;
  }

  @override
  Future<List<Movement>> listByDay({
    required String vendorUid,
    required DateTime start,
    required DateTime end,
  }) async {
    final from = start.toUtc();
    final to = end.toUtc();
    return items.where((item) {
      if (item.vendorUid != vendorUid || item.voided) return false;
      final at = item.occurredAt.toUtc();
      return !at.isBefore(from) && at.isBefore(to);
    }).toList();
  }

  @override
  Future<List<Movement>> listByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    return items
        .where((item) => item.vendorUid == vendorUid && item.clientId == clientId)
        .toList();
  }

  @override
  Future<Movement> updateDetails({
    required String vendorUid,
    required String id,
    required MovementKind kind,
    required int amountCents,
    required DateTime occurredAt,
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(
      kind: kind,
      amountCents: amountCents,
      occurredAt: occurredAt,
    );
    return items[index];
  }

  @override
  Future<void> voidById({
    required String vendorUid,
    required String id,
  }) async {
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(voided: true);
  }

  @override
  Future<void> syncPending(String vendorUid) async {}
}

class _FakeVoiceGateway implements VoiceCaptureGateway {
  @override
  Future<bool> ensureReady() async => true;

  @override
  Future<void> start({
    required void Function(VoiceTranscript transcript) onTranscript,
    required void Function(String message) onError,
    required void Function() onDone,
    void Function()? onStarted,
    void Function(double level)? onSoundLevel,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _SilentPlayback implements VoicePlaybackGateway {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

class _FakeBuyerRemote implements BuyerRemoteDataSource {
  @override
  Future<InviteLookup?> fetchInvite(String code) async => null;

  @override
  Future<void> claimAndLink({
    required String code,
    required String buyerUid,
    required LinkedAccount account,
  }) async {}

  @override
  Future<Client?> fetchClient({
    required String vendorUid,
    required String clientId,
  }) async => null;

  @override
  Future<List<Movement>> fetchMovements({
    required String vendorUid,
    required String clientId,
    int? limit,
  }) async => const [];

  @override
  Future<String> fetchVendorName(String vendorUid) async => '';

  @override
  Future<List<LinkedAccount>> fetchLinks(String buyerUid) async => const [];

  @override
  Future<void> saveLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {}

  @override
  Future<void> ensureVendorMarker({
    required String buyerUid,
    required LinkedAccount account,
  }) async {}

  @override
  Future<void> removeLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {}
}

class _SilentInbox implements PanInboxRemote {
  @override
  Future<void> send({
    required String vendorUid,
    required String buyerUid,
    required String clientId,
    required String clientName,
  }) async {}

  @override
  Stream<List<PanRequest>> watch(String vendorUid) =>
      Stream<List<PanRequest>>.value(const []);

  @override
  Future<void> markSeen({
    required String vendorUid,
    required String buyerUid,
  }) async {}
}

class _FakeGps implements LocationGateway {
  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<GeoFix?> readFix() async {
    return const GeoFix(latitude: -12.05, longitude: -77.04);
  }

  @override
  Stream<GeoFix> watch() => const Stream<GeoFix>.empty();
}

class _SilentPresenceRemote implements PresenceRemoteDataSource {
  @override
  Future<void> publish(String vendorUid, VendorPresence presence) async {}

  @override
  Future<VendorPresence?> fetch(String vendorUid) async => null;

  @override
  Stream<VendorPresence?> watch(String vendorUid) =>
      const Stream<VendorPresence?>.empty();

  @override
  Stream<List<VendorOnRoute>> watchAllOnRoute() =>
      const Stream<List<VendorOnRoute>>.empty();
}

({
  AuthViewModel auth,
  RoleViewModel role,
  AdminAccountsViewModel admin,
  ClientViewModel client,
  BuyerViewModel buyer,
  VoiceCaptureViewModel voice,
  PresenceViewModel presence,
  BuyerMapViewModel map,
  DebtorRadarViewModel radar,
  VendorInboxViewModel inbox,
  LookViewModel look,
})
_buildViewModels({
  required AuthRepository authRepository,
  required RoleRepository roleRepository,
  ClientRepository? clientRepository,
  List<Client> seedClients = const [],
  List<Movement> seedMovements = const [],
}) {
  final observeAuthState = ObserveAuthState(authRepository);
  final fakeClients = _FakeClientRepository()..stored.addAll(seedClients);
  final clients = clientRepository ?? fakeClients;
  final movements = _FakeMovementRepository()..items.addAll(seedMovements);
  final clientViewModel = ClientViewModel(
      observeAuthState: observeAuthState,
      listClients: ListClients(clients),
      registerClient: RegisterClient(clients),
      updateClientUseCase: UpdateClient(clients),
      setClientHouseUseCase: SetClientHouse(clients),
      deactivateClientUseCase: DeactivateClient(clients),
      syncClients: SyncClients(clients),
      syncMovements: SyncMovements(movements),
      recordMovement: RecordMovement(movements),
      listBalances: ListBalances(movements),
      listClientMovements: ListClientMovements(movements),
      updateMovementUseCase: UpdateMovement(movements),
      voidMovementUseCase: VoidMovement(movements),
    );
  return (
    auth: AuthViewModel(
      observeAuthState: observeAuthState,
      signInWithGoogle: SignInWithGoogle(authRepository),
      signOutUseCase: SignOut(authRepository),
    ),
    role: RoleViewModel(
      observeAuthState: observeAuthState,
      loadAccount: LoadAccount(roleRepository),
    ),
    admin: AdminAccountsViewModel(
      listAccounts: ListAccounts(roleRepository),
      assignRole: AssignRole(roleRepository),
    ),
    client: clientViewModel,
    buyer: BuyerViewModel(
      observeAuthState: observeAuthState,
      store: LinkedAccountStore.memory(),
      remote: _FakeBuyerRemote(),
      inbox: _SilentInbox(),
    ),
    voice: VoiceCaptureViewModel(
      capture: _FakeVoiceGateway(),
      playback: _SilentPlayback(),
      applySearchByVoice: ({required spokenQuery}) {
        return clientViewModel.applySearchByVoice(spokenQuery: spokenQuery);
      },
    ),
    presence: PresenceViewModel(
      observeAuthState: observeAuthState,
      location: _FakeGps(),
      remote: _SilentPresenceRemote(),
      store: PresenceLocalStore.memory(),
    ),
    map: BuyerMapViewModel(remote: _SilentPresenceRemote()),
    radar: DebtorRadarViewModel(store: RadarMuteStore.memory()),
    inbox: VendorInboxViewModel(
      observeAuthState: observeAuthState,
      remote: _SilentInbox(),
    ),
    look: LookViewModel(store: LookStore.memory()),
  );
}

void main() {
  testWidgets('muestra el botón de inicio de sesión con Google', (tester) async {
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(null),
      roleRepository: _FakeRoleRepository(),
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();

    expect(find.text('Entrar con Google'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('una cuenta nueva entra como cliente, sin elegir rol', (
    tester,
  ) async {
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: _FakeRoleRepository(),
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Soy vendedor'), findsNothing);
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Vincular'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('la casa del vendedor es de voz y lleva a la lista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Mi ruta'), findsOneWidget);
    expect(find.byTooltip('Pedidos de pan'), findsOneWidget);
    expect(find.text('Hablar'), findsOneWidget);
    expect(find.text('Pulsa Hablar. Di: fiado a María 10 soles'), findsOneWidget);
    expect(find.text('Mis clientes'), findsOneWidget);
    expect(find.text('Anotar pedido'), findsOneWidget);
    expect(find.text('Cuadre del día'), findsOneWidget);
    expect(find.text('Avisar'), findsOneWidget);
    expect(find.text('Estoy en ruta'), findsOneWidget);
    expect(find.text('Aún no tienes clientes'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('¿Qué puedo decir?'));
    await tester.pumpAndSettle();
    expect(find.text('Qué puedo decir'), findsOneWidget);
    expect(find.text('«Fiado a María 5000»'), findsOneWidget);
    expect(find.text('«Cuánto debe María»'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mis clientes'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Aún no hay clientes.\nDi: nuevo cliente María.'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('los recados se ven en una ventana, no en la casa', (
    tester,
  ) async {
    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Nadie te pidió pan.'), findsNothing);
    expect(find.text('Pedidos de pan'), findsNothing);

    await tester.tap(find.byTooltip('Pedidos de pan'));
    await tester.pumpAndSettle();

    expect(find.text('Pedidos de pan'), findsOneWidget);
    expect(find.text('Nadie te pidió pan.'), findsOneWidget);
    expect(find.text('Hablar'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('la pantalla del vendedor usa textos grandes y alto contraste', (
    tester,
  ) async {
    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    final title = tester.widget<Text>(find.text('Mi ruta'));
    expect(title.style?.fontSize, 22);
    expect(title.style?.color, const Color(0xFF2C1810));

    final nuevo = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nuevo cliente'));
    expect(nuevo.style?.backgroundColor?.resolve({}), const Color(0xFF4A2C11));

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('se puede volver al diseño original desde el menú', (
    tester,
  ) async {
    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver al diseño original'));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Mi ruta'));
    expect(title.style?.color, const Color(0xFF111111));
    final nuevo = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nuevo cliente'),
    );
    expect(nuevo.style?.backgroundColor?.resolve({}), const Color(0xFF111111));

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('busca, filtra por deuda y abre el detalle del cliente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
      seedClients: [
        Client(
          id: 'm',
          vendorUid: 'uid123',
          name: 'María',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        Client(
          id: 'j',
          vendorUid: 'uid123',
          name: 'Juan',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
      seedMovements: [
        Movement(
          id: 'mv1',
          vendorUid: 'uid123',
          clientId: 'm',
          kind: MovementKind.fiado,
          amountCents: 500000,
          occurredAt: DateTime(2026, 8, 1),
          createdAt: DateTime(2026, 8, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Mis clientes'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Con deuda'), findsOneWidget);
    expect(find.text('Al día'), findsOneWidget);
    expect(find.text('María'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mar');
    await tester.pump();
    expect(find.text('María'), findsOneWidget);
    expect(find.text('Juan'), findsNothing);

    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pump();
    expect(find.text('Juan'), findsOneWidget);

    await tester.tap(find.text('Con deuda'));
    await tester.pump();
    expect(find.text('María'), findsOneWidget);
    expect(find.text('Juan'), findsNothing);

    await tester.tap(find.text('Al día'));
    await tester.pump();
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('María'), findsNothing);

    await tester.tap(find.text('Todos'));
    await tester.pump();
    await tester.tap(find.text('María'));
    await tester.pumpAndSettle();

    expect(find.text('Movimientos'), findsOneWidget);
    expect(find.text('Anotar fiado o pago'), findsOneWidget);
    expect(find.bySemanticsLabel('Debe S/ 5,000.00'), findsOneWidget);
    expect(find.text('Código para que vea su deuda'), findsOneWidget);

    // Lo de una vez por cliente vive en el menú, no compite con anotar.
    await tester.tap(find.byTooltip('Más opciones del cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Editar datos'), findsOneWidget);
    expect(find.text('Marcar casa'), findsOneWidget);
    expect(find.text('Desactivar cliente'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('buscar por voz desde la casa abre la lista ya filtrada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
      seedClients: [
        Client(
          id: 'm',
          vendorUid: 'uid123',
          name: 'María',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        Client(
          id: 'j',
          vendorUid: 'uid123',
          name: 'Juan',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mi ruta'), findsOneWidget);

    await vms.client.applySearchByVoice(spokenQuery: 'María');
    await tester.pumpAndSettle();

    expect(find.text('Juan'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'María',
    );

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('el cliente ve la pantalla para vincular su deuda', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.cliente;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Vincular'), findsOneWidget);
    expect(find.text('Cambiar rol'), findsNothing);
    final title = tester.widget<Text>(find.text('Mi cuenta'));
    expect(title.style?.fontSize, 18);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('el historial se muestra por tandas con Ver más', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
      seedClients: [
        Client(
          id: 'm',
          vendorUid: 'uid123',
          name: 'María',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
      seedMovements: [
        for (var i = 1; i <= 7; i++)
          Movement(
            id: 'mv$i',
            vendorUid: 'uid123',
            clientId: 'm',
            kind: MovementKind.fiado,
            amountCents: i * 100,
            occurredAt: DateTime(2026, 8, i),
            createdAt: DateTime(2026, 8, i),
          ),
      ],
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Mis clientes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('María'));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 5 de 7'), findsOneWidget);
    expect(find.text('Ver menos'), findsNothing);

    await tester.tap(find.text('Ver 2 más'));
    await tester.pump();

    expect(find.text('Mostrando 7 de 7'), findsOneWidget);
    expect(find.text('Ver menos'), findsOneWidget);

    await tester.tap(find.text('Ver menos'));
    await tester.pump();
    expect(find.text('Mostrando 5 de 7'), findsOneWidget);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('al guardar un cliente se limpia el buscador y aparece', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.vendedor;
    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
      seedClients: [
        Client(
          id: 'j',
          vendorUid: 'uid123',
          name: 'Juan',
          phone: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Mis clientes'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.tap(find.text('Con deuda'));
    await tester.pump();
    expect(find.text('Nadie coincide con esa búsqueda o filtro.'), findsOneWidget);

    await vms.client.addClient(name: 'Ander', phone: '');
    await tester.pump();
    await tester.pump();

    expect(find.text('Ander'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });

  testWidgets('solo el administrador ve el panel de cuentas', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roleRepo = _FakeRoleRepository()..stored = UserRole.admin;
    roleRepo.accounts.addAll(const [
      AccountProfile(
        uid: 'uid123',
        email: 'ana@pan.com',
        displayName: 'Ana',
        role: UserRole.admin,
      ),
      AccountProfile(
        uid: 'uid999',
        email: 'luis@pan.com',
        displayName: 'Luis',
        role: UserRole.cliente,
      ),
    ]);

    final vms = _buildViewModels(
      authRepository: _FakeAuthRepository(
        const UserSession(
          uid: 'uid123',
          email: 'ana@pan.com',
          displayName: 'Ana',
        ),
      ),
      roleRepository: roleRepo,
    );

    await tester.pumpWidget(
      DaleUApp(
        authViewModel: vms.auth,
        roleViewModel: vms.role,
        adminAccountsViewModel: vms.admin,
        clientViewModel: vms.client,
        buyerViewModel: vms.buyer,
        voiceCaptureViewModel: vms.voice,
        presenceViewModel: vms.presence,
        buyerMapViewModel: vms.map,
        radarViewModel: vms.radar,
        vendorInboxViewModel: vms.inbox,
        lookViewModel: vms.look,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mi ruta'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuentas y vendedores'));
    await tester.pumpAndSettle();

    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('Ana (tú)'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);

    await tester.tap(find.text('Luis'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Vendedor'));
    await tester.pumpAndSettle();

    expect(roleRepo.assigned['uid999'], UserRole.vendedor);

    vms.auth.dispose();
    vms.role.dispose();
    vms.admin.dispose();
    vms.client.dispose();
    vms.buyer.dispose();
    vms.voice.dispose();
    vms.presence.dispose();
    vms.map.dispose();
    vms.radar.dispose();
    vms.inbox.dispose();
    vms.look.dispose();
  });
}
