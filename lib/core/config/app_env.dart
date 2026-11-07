import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración inyectada en compile-time con `--dart-define-from-file=.env`.
///
/// Las llaves nunca viven en el código fuente. Si falta un valor obligatorio
/// para la plataforma actual, [validate] lanza un error explícito.
final class AppEnv {
  const AppEnv._();

  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static const firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );

  static const firebaseIosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );

  /// Client ID web (tipo 3). Obligatorio para obtener `idToken` en Android.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Client ID iOS. Se pasa a `GoogleSignIn.initialize` (no va en Info.plist).
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static FirebaseOptions get firebaseOptions {
    if (_isIos) {
      return FirebaseOptions(
        apiKey: firebaseIosApiKey,
        appId: firebaseIosAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        storageBucket: firebaseStorageBucket,
        iosBundleId: firebaseIosBundleId,
      );
    }
    return FirebaseOptions(
      apiKey: firebaseAndroidApiKey,
      appId: firebaseAndroidAppId,
      messagingSenderId: firebaseMessagingSenderId,
      projectId: firebaseProjectId,
      storageBucket: firebaseStorageBucket,
    );
  }

  /// Falla rápido si el arranque no tiene secretos de la plataforma.
  static void validate() {
    final missing = <String>[];

    void require(String name, String value) {
      if (value.trim().isEmpty) missing.add(name);
    }

    require('FIREBASE_PROJECT_ID', firebaseProjectId);
    require('FIREBASE_MESSAGING_SENDER_ID', firebaseMessagingSenderId);
    require('GOOGLE_WEB_CLIENT_ID', googleWebClientId);

    if (_isIos) {
      require('FIREBASE_IOS_API_KEY', firebaseIosApiKey);
      require('FIREBASE_IOS_APP_ID', firebaseIosAppId);
      require('FIREBASE_IOS_BUNDLE_ID', firebaseIosBundleId);
      require('GOOGLE_IOS_CLIENT_ID', googleIosClientId);
    } else {
      require('FIREBASE_ANDROID_API_KEY', firebaseAndroidApiKey);
      require('FIREBASE_ANDROID_APP_ID', firebaseAndroidAppId);
    }

    if (missing.isNotEmpty) {
      throw StateError(
        'Faltan variables en .env: ${missing.join(', ')}. '
        'Copia .env.example a .env y ejecuta con --dart-define-from-file=.env',
      );
    }
  }
}
