import 'package:dale_u/app/dale_u_app.dart';
import 'package:dale_u/app/di/app_container.dart';
import 'package:dale_u/core/config/app_env.dart';
import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/splash/eating_bread.dart';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Primero el pan: la espera se ve mientras Firebase y SQLite arrancan.
  runApp(const EatingBreadSplash());

  try {
    AppEnv.validate();
    await Firebase.initializeApp(options: AppEnv.firebaseOptions);
    await _startCrashReports();
    await _startAppCheck();

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
        statementLinks: container.statementLinks,
        pushRegistrar: container.pushRegistrar,
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

/// Los cierres inesperados llegan a Crashlytics. En modo debug no se envía
/// nada: los errores se ven en la consola.
Future<void> _startCrashReports() async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Prueba ante Firebase que la petición viene de la app real (Play
/// Integrity). Mientras no se active "Exigir" en la consola, solo mide.
Future<void> _startAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (error) {
    // Sin App Check la app funciona igual mientras no se exija.
    debugPrint('App Check unavailable: ${error.runtimeType}');
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
