import 'dart:convert';

import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Copia local de la libreta de vínculos, para abrir la pantalla sin señal.
/// La verdad está en `buyers/{uid}/links`; esto es solo un recuerdo.
class LinkedAccountStore {
  LinkedAccountStore(this._preferences) : _memory = null;

  LinkedAccountStore.memory()
    : _preferences = null,
      _memory = <String, String>{};

  final SharedPreferences? _preferences;
  final Map<String, String>? _memory;

  static const _prefix = 'daleu_links_';
  static const _legacyPrefix = 'daleu_link_';

  String? _get(String key) {
    return _memory?[key] ?? _preferences?.getString(key);
  }

  Future<void> _set(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _preferences!.setString(key, value);
  }

  Future<void> _remove(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }
    await _preferences!.remove(key);
  }

  Future<List<LinkedAccount>> read(String buyerUid) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return const [];

    final raw = _get('$_prefix$uid');
    if (raw == null || raw.isEmpty) return _readLegacy(uid);

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final accounts = <LinkedAccount>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final account = _fromMap(item);
        if (account != null) accounts.add(account);
      }
      return accounts;
    } catch (error) {
      debugPrint('Linked accounts cache unreadable: ${error.runtimeType}');
      return const [];
    }
  }

  Future<void> save({
    required String buyerUid,
    required List<LinkedAccount> accounts,
  }) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return;
    final payload = accounts
        .map(
          (account) => {
            'vendorUid': account.vendorUid,
            'clientId': account.clientId,
            'vendorName': account.vendorName,
          },
        )
        .toList(growable: false);
    await _set('$_prefix$uid', jsonEncode(payload));
    await _remove('$_legacyPrefix$uid');
  }

  Future<void> clear(String buyerUid) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return;
    await _remove('$_prefix$uid');
    await _remove('$_legacyPrefix$uid');
  }

  /// Vínculo único guardado por la versión anterior: no se pierde.
  Future<List<LinkedAccount>> _readLegacy(String uid) async {
    final raw = _get('$_legacyPrefix$uid');
    if (raw == null || raw.isEmpty) return const [];
    final parts = raw.split('|');
    if (parts.length != 2) return const [];
    final vendorUid = InputSanitizer.uid(parts[0]);
    final clientId = InputSanitizer.uid(parts[1]);
    if (vendorUid == null || clientId == null) return const [];
    return [LinkedAccount(vendorUid: vendorUid, clientId: clientId)];
  }

  LinkedAccount? _fromMap(Map<dynamic, dynamic> item) {
    final vendorUid = InputSanitizer.uid(item['vendorUid'] as String?);
    final clientId = InputSanitizer.uid(item['clientId'] as String?);
    if (vendorUid == null || clientId == null) return null;
    return LinkedAccount(
      vendorUid: vendorUid,
      clientId: clientId,
      vendorName: vendorNameOrEmpty(item['vendorName'] as String?),
    );
  }
}
