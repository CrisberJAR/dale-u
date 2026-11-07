import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/error/notice_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/notice/data/notice_remote.dart';
import 'package:dale_u/features/notice/domain/vendor_notice.dart';
import 'package:flutter/foundation.dart';

class FirestoreNoticeRemote implements NoticeRemote {
  FirestoreNoticeRemote({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);
  static const _chunkSize = 400;

  @override
  Future<void> sendToBuyers({
    required String vendorUid,
    required String vendorName,
    required String body,
    required List<String> buyerUids,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final name = InputSanitizer.displayName(vendorName);
    final text = InputSanitizer.notice(body);
    if (vendor == null || text == null) {
      throw const NoticeException('No se pudo enviar el aviso.');
    }
    final buyers = <String>{};
    for (final raw in buyerUids) {
      final id = InputSanitizer.uid(raw);
      if (id != null) buyers.add(id);
    }
    if (buyers.isEmpty) {
      throw const NoticeException(
        'Nadie tiene la app vinculada todavía.',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = buyers.toList();
    try {
      for (var i = 0; i < ids.length; i += _chunkSize) {
        final end = i + _chunkSize > ids.length ? ids.length : i + _chunkSize;
        final batch = firestore.batch();
        for (final buyer in ids.sublist(i, end)) {
          batch.set(_doc(buyer, vendor), {
            'vendorUid': vendor,
            'vendorName': name,
            'body': text,
            'createdAt': now,
            'seen': false,
          });
        }
        await batch.commit().timeout(_timeout);
      }
    } on FirebaseException catch (error) {
      throw NoticeException(_map(error));
    }
  }

  @override
  Stream<List<VendorNotice>> watchBuyer(String buyerUid) {
    final buyer = InputSanitizer.uid(buyerUid);
    if (buyer == null) return Stream<List<VendorNotice>>.value(const []);
    return firestore
        .collection('buyers')
        .doc(buyer)
        .collection('alerts')
        .snapshots()
        .map((snapshot) {
          final notices = <VendorNotice>[];
          for (final doc in snapshot.docs) {
            final parsed = _from(doc.id, doc.data());
            if (parsed != null) notices.add(parsed);
          }
          notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notices;
        });
  }

  @override
  Future<void> markSeen({
    required String buyerUid,
    required String vendorUid,
  }) async {
    final buyer = InputSanitizer.uid(buyerUid);
    final vendor = InputSanitizer.uid(vendorUid);
    if (buyer == null || vendor == null) return;
    try {
      await _doc(buyer, vendor).delete().timeout(_timeout);
    } on FirebaseException catch (error) {
      debugPrint('Remove notice failed: ${error.code}');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String buyer, String vendor) {
    return firestore
        .collection('buyers')
        .doc(buyer)
        .collection('alerts')
        .doc(vendor);
  }

  VendorNotice? _from(String id, Map<String, dynamic> data) {
    if (data['seen'] == true) return null;
    final vendor = InputSanitizer.uid(data['vendorUid'] as String?) ??
        InputSanitizer.uid(id);
    final created = _asMillis(data['createdAt']);
    final body = InputSanitizer.notice(data['body'] as String?);
    if (vendor == null || created == null || body == null) return null;
    return VendorNotice(
      vendorUid: vendor,
      vendorName: InputSanitizer.displayName(data['vendorName'] as String?),
      body: body,
      createdAt: fromEpochMillis(created),
    );
  }

  int? _asMillis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  String _map(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'No se pudo avisar. ¿El cliente sigue vinculado?';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sin señal. Inténtalo en un momento.';
      default:
        return 'No se pudo enviar el aviso (${error.code}).';
    }
  }
}
