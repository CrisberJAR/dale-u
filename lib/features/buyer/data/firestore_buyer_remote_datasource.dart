import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/buyer/data/buyer_remote_datasource.dart';
import 'package:dale_u/features/buyer/domain/buyer_exception.dart';
import 'package:dale_u/features/buyer/domain/linked_account.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/invite_code.dart';
import 'package:dale_u/features/ledger/data/movement_amount.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';
import 'package:flutter/foundation.dart';

class FirestoreBuyerRemoteDataSource implements BuyerRemoteDataSource {
  FirestoreBuyerRemoteDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<InviteLookup?> fetchInvite(String code) async {
    final parsed = InviteCode.parse(code);
    if (parsed == null) return null;
    try {
      final snapshot = await firestore
          .collection('invites')
          .doc(parsed)
          .get()
          .timeout(_timeout);
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final vendorUid = InputSanitizer.uid(data['vendorUid'] as String?);
      final clientId = InputSanitizer.uid(data['clientId'] as String?);
      if (vendorUid == null || clientId == null) return null;
      return InviteLookup(
        vendorUid: vendorUid,
        clientId: clientId,
        active: data['active'] != false,
        linkedUid: InputSanitizer.uid(data['linkedUid'] as String?) ?? '',
        vendorName: vendorNameOrEmpty(data['vendorName'] as String?),
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> claimInvite({
    required String code,
    required String buyerUid,
  }) async {
    final parsed = InviteCode.parse(code);
    final uid = InputSanitizer.uid(buyerUid);
    if (parsed == null || uid == null) {
      throw const BuyerException('Ese código no es válido.');
    }
    try {
      await firestore.collection('invites').doc(parsed).update({
        'linkedUid': uid,
      }).timeout(_timeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> linkClient({
    required String vendorUid,
    required String clientId,
    required String buyerUid,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final client = InputSanitizer.uid(clientId);
    final uid = InputSanitizer.uid(buyerUid);
    if (vendor == null || client == null || uid == null) {
      throw const BuyerException('No se pudo vincular la cuenta.');
    }
    try {
      await firestore
          .collection('vendors')
          .doc(vendor)
          .collection('clients')
          .doc(client)
          .update({
            'linkedUid': uid,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          })
          .timeout(_timeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<Client?> fetchClient({
    required String vendorUid,
    required String clientId,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final client = InputSanitizer.uid(clientId);
    if (vendor == null || client == null) return null;
    try {
      final snapshot = await firestore
          .collection('vendors')
          .doc(vendor)
          .collection('clients')
          .doc(client)
          .get()
          .timeout(_timeout);
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      final name = InputSanitizer.personName(data['name'] as String?);
      final createdAt = _asMillis(data['createdAt']);
      final updatedAt = _asMillis(data['updatedAt']);
      if (name == null || createdAt == null || updatedAt == null) return null;
      return Client(
        id: client,
        vendorUid: vendor,
        name: name,
        phone: InputSanitizer.phone(data['phone'] as String?),
        createdAt: fromEpochMillis(createdAt),
        updatedAt: fromEpochMillis(updatedAt),
        pendingSync: false,
        active: data['active'] != false,
        inviteCode: InviteCode.parse(data['inviteCode'] as String?) ?? '',
        linkedUid: InputSanitizer.uid(data['linkedUid'] as String?) ?? '',
      );
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<List<Movement>> fetchMovements({
    required String vendorUid,
    required String clientId,
  }) async {
    final vendor = InputSanitizer.uid(vendorUid);
    final client = InputSanitizer.uid(clientId);
    if (vendor == null || client == null) return const [];
    try {
      final snapshot = await firestore
          .collection('vendors')
          .doc(vendor)
          .collection('clients')
          .doc(client)
          .collection('movements')
          .get()
          .timeout(_timeout);
      final movements = <Movement>[];
      for (final doc in snapshot.docs) {
        final parsed = _movementFrom(vendor, client, doc.id, doc.data());
        if (parsed != null) movements.add(parsed);
      }
      movements.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return movements;
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  Movement? _movementFrom(
    String vendorUid,
    String clientId,
    String id,
    Map<String, dynamic> data,
  ) {
    final safeId = InputSanitizer.uid(id);
    final kind = MovementKind.tryParse(data['kind'] as String? ?? '');
    if (safeId == null || kind == null) return null;
    final amountCents = readAmountCents(data);
    final occurredAt = _asMillis(data['occurredAt']);
    final createdAt = _asMillis(data['createdAt']);
    if (amountCents == null || occurredAt == null || createdAt == null) {
      return null;
    }
    return Movement(
      id: safeId,
      vendorUid: vendorUid,
      clientId: clientId,
      kind: kind,
      amountCents: amountCents,
      occurredAt: fromEpochMillis(occurredAt),
      createdAt: fromEpochMillis(createdAt),
      pendingSync: false,
      voided: data['voided'] == true,
    );
  }

  @override
  Future<String> fetchVendorName(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return '';
    try {
      final snapshot = await firestore
          .collection('vendors')
          .doc(uid)
          .get()
          .timeout(_timeout);
      return vendorNameOrEmpty(snapshot.data()?['displayName'] as String?);
    } on FirebaseException catch (error) {
      debugPrint('Vendor name unavailable: ${error.code}');
      return '';
    }
  }

  @override
  Future<List<LinkedAccount>> fetchLinks(String buyerUid) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return const [];
    try {
      final snapshot = await _links(uid).get().timeout(_timeout);
      final accounts = <LinkedAccount>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final vendorUid = InputSanitizer.uid(data['vendorUid'] as String?);
        final clientId = InputSanitizer.uid(data['clientId'] as String?);
        if (vendorUid == null || clientId == null) continue;
        accounts.add(
          LinkedAccount(
            vendorUid: vendorUid,
            clientId: clientId,
            vendorName: vendorNameOrEmpty(data['vendorName'] as String?),
          ),
        );
      }
      return accounts;
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> saveLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return;
    try {
      await _links(uid).doc(account.id).set({
        'vendorUid': account.vendorUid,
        'clientId': account.clientId,
        'vendorName': account.vendorName,
        'linkedAt': DateTime.now().millisecondsSinceEpoch,
      }).timeout(_timeout);
      await _writeVendorMarker(uid, account);
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> removeLink({
    required String buyerUid,
    required LinkedAccount account,
  }) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return;
    try {
      await _links(uid).doc(account.id).delete().timeout(_timeout);
      await firestore
          .collection('buyers')
          .doc(uid)
          .collection('vendors')
          .doc(account.vendorUid)
          .delete()
          .timeout(_timeout);
    } on FirebaseException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> ensureVendorMarker({
    required String buyerUid,
    required LinkedAccount account,
  }) async {
    final uid = InputSanitizer.uid(buyerUid);
    if (uid == null) return;
    try {
      await _writeVendorMarker(uid, account);
    } on FirebaseException catch (error) {
      debugPrint('Vendor marker failed: ${error.code}');
    }
  }

  Future<void> _writeVendorMarker(String uid, LinkedAccount account) {
    return firestore
        .collection('buyers')
        .doc(uid)
        .collection('vendors')
        .doc(account.vendorUid)
        .set({'clientId': account.clientId})
        .timeout(_timeout);
  }

  CollectionReference<Map<String, dynamic>> _links(String buyerUid) {
    return firestore.collection('buyers').doc(buyerUid).collection('links');
  }

  BuyerException _map(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return const BuyerException(
          'Firebase no dejó vincular. Revisa el código o pide uno nuevo.',
        );
      case 'not-found':
        return const BuyerException('Ese código no existe.');
      case 'unavailable':
      case 'deadline-exceeded':
        return const BuyerException('Sin señal. Inténtalo en un momento.');
      default:
        return BuyerException('No se pudo consultar la nube (${error.code}).');
    }
  }

  int? _asMillis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
