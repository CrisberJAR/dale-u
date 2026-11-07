import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/buyer/domain/buyer_exception.dart';
import 'package:dale_u/features/inbox/data/pan_inbox_remote.dart';
import 'package:dale_u/features/inbox/domain/pan_request.dart';
import 'package:flutter/foundation.dart';

class FirestorePanInboxRemote implements PanInboxRemote {
  FirestorePanInboxRemote({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<void> send({
    required String vendorUid,
    required String buyerUid,
    required String clientId,
    required String clientName,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final buyer = InputSanitizer.uid(buyerUid);
    final client = InputSanitizer.uid(clientId);
    final name = InputSanitizer.personName(clientName);
    if (vendor == null || buyer == null || client == null || name == null) {
      throw const BuyerException('No se pudo enviar el recado.');
    }
    try {
      await _doc(vendor, buyer).set({
        'buyerUid': buyer,
        'clientId': client,
        'clientName': name,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'seen': false,
      }).timeout(_timeout);
    } on FirebaseException catch (error) {
      throw BuyerException(_map(error));
    }
  }

  @override
  Stream<List<PanRequest>> watch(String vendorUid) {
    final vendor = InputSanitizer.uid(vendorUid);
    if (vendor == null) return Stream<List<PanRequest>>.value(const []);
    return firestore
        .collection('vendors')
        .doc(vendor)
        .collection('inbox')
        .snapshots()
        .map((snapshot) {
          final requests = <PanRequest>[];
          for (final doc in snapshot.docs) {
            final parsed = _from(doc.id, doc.data());
            if (parsed != null && !parsed.seen) requests.add(parsed);
          }
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  @override
  Future<void> markSeen({
    required String vendorUid,
    required String buyerUid,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final buyer = InputSanitizer.uid(buyerUid);
    if (vendor == null || buyer == null) return;
    try {
      await _doc(vendor, buyer).delete().timeout(_timeout);
    } on FirebaseException catch (error) {
      debugPrint('Remove pan request failed: ${error.code}');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String vendor, String buyer) {
    return firestore
        .collection('vendors')
        .doc(vendor)
        .collection('inbox')
        .doc(buyer);
  }

  PanRequest? _from(String id, Map<String, dynamic> data) {
    final buyer = InputSanitizer.uid(data['buyerUid'] as String?) ??
        InputSanitizer.uid(id);
    final clientId = InputSanitizer.uid(data['clientId'] as String?);
    final created = _asMillis(data['createdAt']);
    if (buyer == null || clientId == null || created == null) return null;
    final name = InputSanitizer.personName(data['clientName'] as String?);
    return PanRequest(
      buyerUid: buyer,
      clientId: clientId,
      clientName: name ?? 'Un cliente',
      createdAt: fromEpochMillis(created),
      seen: data['seen'] == true,
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
        return 'No se pudo pedir el pan. ¿Sigues vinculado?';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sin señal. Inténtalo en un momento.';
      default:
        return 'No se pudo enviar el recado (${error.code}).';
    }
  }
}
