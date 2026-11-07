import 'package:dale_u/core/theme/dale_u_theme.dart';
import 'package:dale_u/core/theme/look_view_model.dart';
import 'package:dale_u/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:dale_u/features/auth/presentation/widgets/auth_gate.dart';
import 'package:dale_u/features/buyer/presentation/viewmodels/buyer_view_model.dart';
import 'package:dale_u/features/client/presentation/viewmodels/client_view_model.dart';
import 'package:dale_u/features/inbox/presentation/viewmodels/vendor_inbox_view_model.dart';
import 'package:dale_u/features/ledger/presentation/viewmodels/daily_close_view_model.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/buyer_notice_view_model.dart';
import 'package:dale_u/features/notice/presentation/viewmodels/vendor_notice_view_model.dart';
import 'package:dale_u/features/orders/presentation/viewmodels/order_view_model.dart';
import 'package:dale_u/features/role/presentation/viewmodels/admin_accounts_view_model.dart';
import 'package:dale_u/features/role/presentation/viewmodels/role_view_model.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/buyer_map_view_model.dart';
import 'package:dale_u/features/presence/presentation/viewmodels/presence_view_model.dart';
import 'package:dale_u/features/proximity/data/push_registrar.dart';
import 'package:dale_u/features/statement/data/statement_link_service.dart';
import 'package:dale_u/features/radar/presentation/viewmodels/debtor_radar_view_model.dart';
import 'package:dale_u/features/radar/presentation/widgets/debtor_radar_listener.dart';
import 'package:dale_u/features/voice/presentation/viewmodels/voice_capture_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

class DaleUApp extends StatelessWidget {
  DaleUApp({
    super.key,
    required this.authViewModel,
    required this.roleViewModel,
    required this.adminAccountsViewModel,
    required this.clientViewModel,
    required this.buyerViewModel,
    required this.voiceCaptureViewModel,
    required this.presenceViewModel,
    required this.buyerMapViewModel,
    required this.radarViewModel,
    required this.vendorInboxViewModel,
    required this.lookViewModel,
    OrderViewModel? orderViewModel,
    DailyCloseViewModel? dailyCloseViewModel,
    VendorNoticeViewModel? vendorNoticeViewModel,
    BuyerNoticeViewModel? buyerNoticeViewModel,
    this.statementLinks,
    this.pushRegistrar,
  }) : orderViewModel = orderViewModel ?? OrderViewModel.idle(),
       dailyCloseViewModel =
           dailyCloseViewModel ?? DailyCloseViewModel.idle(),
       vendorNoticeViewModel =
           vendorNoticeViewModel ?? VendorNoticeViewModel.idle(),
       buyerNoticeViewModel =
           buyerNoticeViewModel ?? BuyerNoticeViewModel.idle();

  final AuthViewModel authViewModel;
  final RoleViewModel roleViewModel;
  final AdminAccountsViewModel adminAccountsViewModel;
  final ClientViewModel clientViewModel;
  final BuyerViewModel buyerViewModel;
  final VoiceCaptureViewModel voiceCaptureViewModel;
  final PresenceViewModel presenceViewModel;
  final BuyerMapViewModel buyerMapViewModel;
  final DebtorRadarViewModel radarViewModel;
  final VendorInboxViewModel vendorInboxViewModel;
  final LookViewModel lookViewModel;
  final OrderViewModel orderViewModel;
  final DailyCloseViewModel dailyCloseViewModel;
  final VendorNoticeViewModel vendorNoticeViewModel;
  final BuyerNoticeViewModel buyerNoticeViewModel;

  /// Opcionales: las pruebas de pantalla corren sin Firebase.
  final StatementLinkService? statementLinks;
  final PushRegistrar? pushRegistrar;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ChangeNotifierProvider<RoleViewModel>.value(value: roleViewModel),
        ChangeNotifierProvider<AdminAccountsViewModel>.value(
          value: adminAccountsViewModel,
        ),
        ChangeNotifierProvider<ClientViewModel>.value(value: clientViewModel),
        ChangeNotifierProvider<BuyerViewModel>.value(value: buyerViewModel),
        ChangeNotifierProvider<VoiceCaptureViewModel>.value(
          value: voiceCaptureViewModel,
        ),
        ChangeNotifierProvider<PresenceViewModel>.value(
          value: presenceViewModel,
        ),
        ChangeNotifierProvider<BuyerMapViewModel>.value(
          value: buyerMapViewModel,
        ),
        ChangeNotifierProvider<DebtorRadarViewModel>.value(
          value: radarViewModel,
        ),
        ChangeNotifierProvider<VendorInboxViewModel>.value(
          value: vendorInboxViewModel,
        ),
        ChangeNotifierProvider<OrderViewModel>.value(value: orderViewModel),
        ChangeNotifierProvider<DailyCloseViewModel>.value(
          value: dailyCloseViewModel,
        ),
        ChangeNotifierProvider<VendorNoticeViewModel>.value(
          value: vendorNoticeViewModel,
        ),
        ChangeNotifierProvider<BuyerNoticeViewModel>.value(
          value: buyerNoticeViewModel,
        ),
        ChangeNotifierProvider<LookViewModel>.value(value: lookViewModel),
        Provider<StatementLinkService?>.value(value: statementLinks),
        Provider<PushRegistrar?>.value(value: pushRegistrar),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Para avisos rápidos desde servicios (por ejemplo, un push con la app
/// abierta) sin depender de qué pantalla esté arriba.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    context.watch<LookViewModel>();
    return MaterialApp(
      title: 'Dale U',
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [
        Locale('es', 'PE'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: daleUTheme(),
      home: const DebtorRadarListener(child: AuthGate()),
    );
  }
}
