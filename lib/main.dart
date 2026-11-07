import 'package:dale_u/app/dale_u_app.dart';
import 'package:dale_u/app/di/app_container.dart';
import 'package:dale_u/core/config/app_env.dart';
import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/splash/eating_bread.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Primero el pan: la espera se ve mientras Firebase y SQLite arrancan.
  runApp(const EatingBreadSplash());

  try {
    AppEnv.validate();
    await Firebase.initializeApp(options: AppEnv.firebaseOptions);

    final preferences = await SharedPreferences.getInstance();
    final database = await AppDatabase.open();
    final container = AppContainer(
      preferences: preferences,
      database: database,
    );
    await container.initializeGoogleSignIn();

    runApp(
      DaleUApp(
        authViewModel: container.authViewModel,
        roleViewModel: container.roleViewModel,
        adminAccountsViewModel: container.adminAccountsViewModel,
        clientViewModel: container.clientViewModel,
        buyerViewModel: container.buyerViewModel,
        voiceCaptureViewModel: container.voiceCaptureViewModel,
        presenceViewModel: container.presenceViewModel,
        buyerMapViewModel: container.buyerMapViewModel,
        radarViewModel: container.radarViewModel,
        vendorInboxViewModel: container.vendorInboxViewModel,
        lookViewModel: container.lookViewModel,
        orderViewModel: container.orderViewModel,
        dailyCloseViewModel: container.dailyCloseViewModel,
        vendorNoticeViewModel: container.vendorNoticeViewModel,
        buyerNoticeViewModel: container.buyerNoticeViewModel,
      ),
    );
  } on StateError catch (error) {
    runApp(_BootstrapErrorApp(message: error.message));
  } catch (error) {
    runApp(
      _BootstrapErrorApp(
        message: 'No se pudo abrir la app. Revisa la señal e inténtalo.',
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: splashCream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
