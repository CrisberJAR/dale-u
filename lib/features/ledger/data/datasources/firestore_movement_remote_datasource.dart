import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/error/ledger_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/ledger/data/datasources/movement_remote_datasource.dart';
import 'package:dale_u/features/ledger/data/movement_amount.dart';
import 'package:dale_u/features/ledger/domain/entities/movement.dart';
import 'package:dale_u/features/ledger/domain/entities/movement_kind.dart';

class FirestoreMovementRemoteDataSource implements MovementRemoteDataSource {
  FirestoreMovementRemoteDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);

  CollectionReference<Map<String, dynamic>> _col({
    required String vendorUid,
    required String clientId,
  }) {
    return firestore
        .collection('vendors')
        .doc(vendorUid)
        .collection('clients')
        .doc(clientId)
        .collection('movements');
  }

  @override
  Future<void> upsert(Movement movement) async {
    final vendorUid = InputSanitizer.uid(movement.vendorUid);
    final clientId = InputSanitizer.uid(movement.clientId);
    final movementId = InputSanitizer.uid(movement.id);
    if (vendorUid == null || clientId == null || movementId == null) {
      throw const LedgerException('Movimiento inválido para sincronizar.');
    }
    await _col(vendorUid: vendorUid, clientId: clientId).doc(movementId).set({
      'vendorUid': vendorUid,
      'clientId': clientId,
      'kind': movement.kind.name,
      'amountCents': movement.amountCents,
      'occurredAt': movement.occurredAt.millisecondsSinceEpoch,
      'createdAt': movement.createdAt.millisecondsSinceEpoch,
      'voided': movement.voided,
    }).timeout(_timeout);
  }

  @override
  Future<List<Movement>> fetchByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) return const [];

    final snapshot = await _col(vendorUid: uid, clientId: id).get().timeout(
      _timeout,
    );
    final movements = <Movement>[];
    for (final doc in snapshot.docs) {
      final parsed = _fromDoc(uid, id, doc.id, doc.data());
      if (parsed != null) movements.add(parsed);
    }
    return movements;
  }

  Movement? _fromDoc(
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

  int? _asMillis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
