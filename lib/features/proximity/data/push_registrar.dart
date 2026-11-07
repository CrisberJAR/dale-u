import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Deja el token de este teléfono en `users/{uid}/devices/{instalación}`
/// para que la Cloud Function avise "Tu panadero está cerca".
///
/// Solo para compradores. Como mucho llegan dos avisos por visita del
/// panadero (a 200 m y a 40 m de la casa) y nada más: ni fiados ni pedidos.
class PushRegistrar {
  PushRegistrar({
    required this.preferences,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final SharedPreferences preferences;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  static const _installKey = 'push.installId';

  String? _uid;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;

  /// Con la app abierta el sistema no muestra la notificación: se avisa
  /// aquí (la pantalla del comprador muestra un mensaje).
  void Function(String title, String body)? onForegroundMessage;

  String get _installId {
    final saved = preferences.getString(_installKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final created = const Uuid().v4();
    unawaited(preferences.setString(_installKey, created));
    return created;
  }

  /// Pide permiso (Android 13+ / iOS) y guarda el token. Sin permiso no
  /// pasa nada malo: simplemente no llegan avisos.
  Future<void> register(String uid) async {
    final safe = InputSanitizer.uid(uid);
    if (safe == null) return;
    if (_uid == safe) return;
    _uid = safe;
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await _messaging.getToken();
      if (token != null) await _save(safe, token);
      await _refresh?.cancel();
      _refresh = _messaging.onTokenRefresh.listen((next) {
        final current = _uid;
        if (current != null) unawaited(_save(current, next));
      });
      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        onForegroundMessage?.call(
          notification.title ?? 'Tu panadero',
          notification.body ?? '',
        );
      });
    } catch (error, stack) {
      debugPrint('Push register failed: ${error.runtimeType}');
      debugPrint('$stack');
      _uid = null;
    }
  }

  /// Antes de cerrar sesión: este teléfono deja de recibir avisos de esa
  /// cuenta.
  Future<void> unregister() async {
    final uid = _uid;
    _uid = null;
    await _refresh?.cancel();
    _refresh = null;
    await _foreground?.cancel();
    _foreground = null;
    if (uid == null) return;
    try {
      await _doc(uid).delete();
      await _messaging.deleteToken();
    } catch (error) {
      debugPrint('Push unregister failed: ${error.runtimeType}');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(_installId);
  }

  Future<void> _save(String uid, String token) async {
    try {
      await _doc(uid).set({
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      debugPrint('Push token save failed: ${error.runtimeType}');
    }
  }
}
