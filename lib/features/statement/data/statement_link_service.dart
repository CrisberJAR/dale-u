import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/config/app_env.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enlace al estado de cuenta que va en el WhatsApp.
///
/// El token es largo (40 caracteres al azar, imposible de adivinar) y se
/// reutiliza por cliente: el mismo enlace siempre muestra el saldo al día.
/// La página la arma la Cloud Function `estadoCuenta`; desde la app nadie
/// puede leer `statementLinks`.
class StatementLinkService {
  StatementLinkService({
    required this.preferences,
    FirebaseFirestore? firestore,
    Random? random,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _random = random ?? Random.secure();

  final SharedPreferences preferences;
  final FirebaseFirestore _firestore;
  final Random _random;

  static const tokenLength = 40;
  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static const _timeout = Duration(seconds: 15);

  String _key(String vendorUid, String clientId) =>
      'statement.$vendorUid.$clientId';

  /// Devuelve la URL pública. Necesita señal la primera vez por cliente.
  Future<String> linkFor({
    required String vendorUid,
    required String clientId,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw StateError('Cliente inválido para el enlace.');
    }
    final key = _key(uid, id);
    final saved = preferences.getString(key);
    if (saved != null && saved.length == tokenLength) {
      return urlFor(saved);
    }
    final token = _newToken();
    await _firestore.collection('statementLinks').doc(token).set({
      'vendorUid': uid,
      'clientId': id,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }).timeout(_timeout);
    await preferences.setString(key, token);
    return urlFor(token);
  }

  static String urlFor(String token) {
    final base = AppEnv.statementBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/e/$token';
  }

  String _newToken() {
    final buffer = StringBuffer();
    for (var i = 0; i < tokenLength; i++) {
      buffer.write(_alphabet[_random.nextInt(_alphabet.length)]);
    }
    return buffer.toString();
  }
}
