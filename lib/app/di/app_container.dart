import 'package:dale_u/core/config/app_env.dart';
import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/sync/sync_cursor_store.dart';
import 'package:dale_u/features/proximity/data/push_registrar.dart';
import 'package:dale_u/features/statement/data/statement_link_service.dart';
import 'package:dale_u/features/auth/data/datasources/google_auth_remote_datasource.dart';
import 'package:dale_u/features/auth/data/gateways/google_sign_in_gateway.dart';
import 'package:dale_u/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:dale_u/features/auth/domain/repositories/auth_repository.dart';
import 'package:dale_u/features/auth/domain/usecases/observe_auth_state.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:dale_u/features/auth/domain/usecases/sign_out.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/buyer/data/firestore_buyer_remote_datasource.dart';
import 'package:dale_u/features/buyer/data/linked_account_store.dart';
import 'package:dale_u/features/buyer/presentation/viewmodels/buyer_view_model.dart';
import 'package:dale_u/features/client/data/datasources/client_local_datasource.dart';
import 'package:dale_u/features/client/data/datasources/firestore_client_remote_datasource.dart';
import 'package:dale_u/features/client/data/repositories/client_repository_impl.dart';
import 'package:dale_u/features/client/data/sync/client_sync_engine.dart';
import 'package:dale_u/features/client/data/sync/client_synchronizer.dart';
import 'package:dale_u/features/client/data/sync/stale_client_purger.dart';
import 'package:dale_u/features/ledger/data/datasources/firestore_movement_remote_datasource.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_local_datasource.dart';
import 'package:dale_u/features/ledger/data/repositories/movement_repository_impl.dart';
import 'package:dale_u/features/ledger/data/sync/movement_synchronizer.dart';
import 'package:dale_u/features/client/domain/usecases/deactivate_client.dart';
import 'package:dale_u/features/client/domain/usecases/list_clients.dart';
import 'package:dale_u/features/client/domain/usecases/register_client.dart';
import 'package:dale_u/features/client/domain/usecases/set_client_house.dart';
import 'package:dale_u/features/client/domain/usecases/sync_clients.dart';
import 'package:dale_u/features/client/domain/usecases/update_client.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_balances.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_client_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/list_day_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/record_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/sync_movements.dart';
import 'package:dale_u/features/ledger/domain/usecases/update_movement.dart';
import 'package:dale_u/features/ledger/domain/usecases/void_movement.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/ledger/presentation/viewmodels/daily_close_view_model.dart';
import 'package:dale_u/features/notice/data/firestore_notice_remote.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/buyer_notice_view_model.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/vendor_notice_view_model.dart';
import 'package:dale_u/features/orders/data/pan_order_local_datasource.dart';
import 'package:dale_u/features/orders/presentation/viewmodels/order_view_model.dart';
import 'package:dale_u/features/role/data/datasources/firestore_account_remote_datasource.dart';
import 'package:dale_u/features/role/data/datasources/role_local_datasource.dart';
import 'package:dale_u/features/role/data/repositories/role_repository_impl.dart';
import 'package:dale_u/features/role/domain/usecases/assign_role.dart';
import 'package:dale_u/features/role/domain/usecases/list_accounts.dart';
import 'package:dale_u/features/role/domain/usecases/load_account.dart';
import 'package:dale_u/features/role/presentation/viewmodels/admin_accounts_view_model.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:dale_u/core/theme/look_store.dart';
import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/features/inbox/data/firestore_pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:dale_u/features/radar/data/radar_mute_store.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/presence/data/datasources/firestore_presence_remote_datasource.dart';
import 'package:dale_u/features/presence/data/geolocator_location_gateway.dart';
import 'package:dale_u/features/presence/data/presence_local_store.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/buyer_map_view_model.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:dale_u/features/voice/data/native_voice_capture_gateway.dart';
import 'package:dale_u/features/voice/data/native_voice_playback_gateway.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppContainer {
  AppContainer({
    required SharedPreferences preferences,
    required AppDatabase database,
    FirebaseAuth? firebaseAuth,
    GoogleSignInGateway? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignInGatewayImpl() {
    final authDataSource = GoogleAuthRemoteDataSource(
      firebaseAuth: firebaseAuth ?? FirebaseAuth.instance,
      googleSignIn: _googleSignIn,
    );
    repository = AuthRepositoryImpl(authDataSource);
    final observeAuthState = ObserveAuthState(repository);
    authViewModel = AuthViewModel(
      observeAuthState: observeAuthState,
      signInWithGoogle: SignInWithGoogle(repository),
      signOutUseCase: SignOut(repository),
    );

    final roleRepository = RoleRepositoryImpl(
      local: RoleLocalDataSource(preferences),
      remote: FirestoreAccountRemoteDataSource(),
    );
    roleViewModel = RoleViewModel(
      observeAuthState: observeAuthState,
      loadAccount: LoadAccount(roleRepository),
    );
    adminAccountsViewModel = AdminAccountsViewModel(
      listAccounts: ListAccounts(roleRepository),
      assignRole: AssignRole(roleRepository),
    );

    final localClients = ClientLocalDataSource(database);
    final remoteClients = FirestoreClientRemoteDataSource(
      vendorNameOf: () => authViewModel.session?.displayName ?? '',
    );
    final localMovements = MovementLocalDataSource(database);
    final localOrders = PanOrderLocalDataSource(database);
    final purger = StaleClientPurger(
      clients: localClients,
      movements: localMovements,
      orders: localOrders,
      remote: remoteClients,
    );
    final synchronizer = ClientSynchronizer(
      local: localClients,
      remote: remoteClients,
      afterPull: (uid) async {
        await purger.run(uid);
      },
    );
    final clientRepository = ClientRepositoryImpl(
      local: localClients,
      synchronizer: synchronizer,
    );
    final syncClients = SyncClients(clientRepository);
    final movementSynchronizer = MovementSynchronizer(
      local: localMovements,
      remote: FirestoreMovementRemoteDataSource(),
      listClientIds: localClients.listIdsByVendor,
      cursors: SyncCursorStore(preferences, scope: 'movements.v2'),
    );
    final movementRepository = MovementRepositoryImpl(
      localMovements,
      synchronizer: movementSynchronizer,
    );
    final recordMovement = RecordMovement(movementRepository);
    final listBalances = ListBalances(movementRepository);
    final syncMovements = SyncMovements(movementRepository);
    clientViewModel = ClientViewModel(
      observeAuthState: observeAuthState,
      listClients: ListClients(clientRepository),
      registerClient: RegisterClient(clientRepository),
      updateClientUseCase: UpdateClient(clientRepository),
      setClientHouseUseCase: SetClientHouse(clientRepository),
      deactivateClientUseCase: DeactivateClient(
        clientRepository,
        balanceOf: ({required vendorUid, required clientId}) async {
          final balances = await listBalances(vendorUid);
          return balances[clientId] ?? 0;
        },
      ),
      syncClients: syncClients,
      syncMovements: syncMovements,
      recordMovement: recordMovement,
      listBalances: listBalances,
      listClientMovements: ListClientMovements(movementRepository),
      updateMovementUseCase: UpdateMovement(movementRepository),
      voidMovementUseCase: VoidMovement(movementRepository),
    );
    orderViewModel = OrderViewModel(
      observeAuthState: observeAuthState,
      local: localOrders,
    );
    clientSyncEngine = ClientSyncEngine(
      observeAuthState: observeAuthState,
      syncClients: syncClients,
      syncMovements: syncMovements,
    );
    final panInbox = FirestorePanInboxRemote();
    final notices = FirestoreNoticeRemote();
    dailyCloseViewModel = DailyCloseViewModel(
      observeAuthState: observeAuthState,
      listDayMovements: ListDayMovements(movementRepository),
    );
    vendorNoticeViewModel = VendorNoticeViewModel(
      observeAuthState: observeAuthState,
      remote: notices,
    );
    buyerNoticeViewModel = BuyerNoticeViewModel(
      observeAuthState: observeAuthState,
      remote: notices,
    );
    final buyerRemote = FirestoreBuyerRemoteDataSource();
    buyerViewModel = BuyerViewModel(
      observeAuthState: observeAuthState,
      store: LinkedAccountStore(preferences),
      remote: buyerRemote,
      inbox: panInbox,
    );
    vendorInboxViewModel = VendorInboxViewModel(
      observeAuthState: observeAuthState,
      remote: panInbox,
    );
    final presenceRemote = FirestorePresenceRemoteDataSource();
    presenceViewModel = PresenceViewModel(
      observeAuthState: observeAuthState,
      location: GeolocatorLocationGateway(),
      remote: presenceRemote,
      store: PresenceLocalStore(preferences),
    );
    buyerMapViewModel = BuyerMapViewModel(
      remote: presenceRemote,
      nameOf: buyerRemote.fetchVendorName,
    );
    radarViewModel = DebtorRadarViewModel(
      store: RadarMuteStore(preferences),
    );
    lookViewModel = LookViewModel(store: LookStore(preferences));
    statementLinks = StatementLinkService(preferences: preferences);
    pushRegistrar = PushRegistrar(preferences: preferences);
    authViewModel.beforeSignOut = pushRegistrar.unregister;
    voiceCaptureViewModel = VoiceCaptureViewModel(
      capture: NativeVoiceCaptureGateway(),
      playback: NativeVoicePlaybackGateway(),
      registerClientByVoice: ({required String name, required String phone}) async {
        final ok = await clientViewModel.addClient(name: name, phone: phone);
        if (ok) return null;
        return clientViewModel.errorMessage ?? 'No se pudo guardar el cliente.';
      },
      recordLedgerByVoice: ({
        required kind,
        required spokenName,
        required amountCents,
      }) {
        return clientViewModel.recordLedgerByVoice(
          kind: kind,
          spokenName: spokenName,
          amountCents: amountCents,
        );
      },
      queryBalanceByVoice: ({required spokenName}) {
        return clientViewModel.queryBalanceByVoice(spokenName: spokenName);
      },
      applySearchByVoice: ({required spokenQuery}) {
        return clientViewModel.applySearchByVoice(spokenQuery: spokenQuery);
      },
      undoLastByVoice: clientViewModel.undoLastVoiceMovement,
    );
  }

  final GoogleSignInGateway _googleSignIn;
  late final AuthRepository repository;
  late final AuthViewModel authViewModel;
  late final RoleViewModel roleViewModel;
  late final AdminAccountsViewModel adminAccountsViewModel;
  late final ClientViewModel clientViewModel;
  late final OrderViewModel orderViewModel;
  late final DailyCloseViewModel dailyCloseViewModel;
  late final VendorNoticeViewModel vendorNoticeViewModel;
  late final BuyerNoticeViewModel buyerNoticeViewModel;
  late final BuyerViewModel buyerViewModel;
  late final VendorInboxViewModel vendorInboxViewModel;
  late final ClientSyncEngine clientSyncEngine;
  late final PresenceViewModel presenceViewModel;
  late final BuyerMapViewModel buyerMapViewModel;
  late final DebtorRadarViewModel radarViewModel;
  late final LookViewModel lookViewModel;
  late final VoiceCaptureViewModel voiceCaptureViewModel;
  late final StatementLinkService statementLinks;
  late final PushRegistrar pushRegistrar;

  Future<void> initializeGoogleSignIn() {
    return _googleSignIn.initialize(
      serverClientId: AppEnv.googleWebClientId,
      clientId: AppEnv.googleIosClientId.isEmpty
          ? null
          : AppEnv.googleIosClientId,
    );
  }
}
