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

  /// La hora del cambio la pone el servidor: así la bajada incremental no
  /// depende del reloj de cada teléfono.
  DocumentReference<Map<String, dynamic>> _ref(Movement movement) {
    final vendorUid = InputSanitizer.uid(movement.vendorUid);
    final clientId = InputSanitizer.uid(movement.clientId);
    final movementId = InputSanitizer.uid(movement.id);
    if (vendorUid == null || clientId == null || movementId == null) {
      throw const LedgerException('Movimiento inválido para sincronizar.');
    }
    return _col(vendorUid: vendorUid, clientId: clientId).doc(movementId);
  }

  Map<String, Object> _payload(Movement movement) {
    return {
      'vendorUid': movement.vendorUid,
      'clientId': movement.clientId,
      'kind': movement.kind.name,
      'amountCents': movement.amountCents,
      'occurredAt': movement.occurredAt.millisecondsSinceEpoch,
      'createdAt': movement.createdAt.millisecondsSinceEpoch,
      'voided': movement.voided,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  Future<void> upsert(Movement movement) async {
    await _ref(movement).set(_payload(movement)).timeout(_timeout);
  }

  @override
  Future<void> upsertAll(List<Movement> movements) async {
    if (movements.isEmpty) return;
    final batch = firestore.batch();
    for (final movement in movements) {
      batch.set(_ref(movement), _payload(movement));
    }
    await batch.commit().timeout(_timeout);
  }

  @override
  Future<MovementChanges> fetchChangedSince({
    required String vendorUid,
    required DateTime since,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return const MovementChanges(movements: []);
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await firestore
          .collectionGroup('movements')
          .where('vendorUid', isEqualTo: uid)
          .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('updatedAt')
          .get()
          .timeout(_timeout);
    } on FirebaseException catch (error) {
      // Sin índice desplegado (o reglas viejas): se baja todo como antes.
      if (error.code == 'failed-precondition' ||
          error.code == 'permission-denied') {
        throw const MovementDeltaUnavailable();
      }
      rethrow;
    }
    final movements = <Movement>[];
    DateTime? cursor;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final clientId = InputSanitizer.uid(data['clientId'] as String?);
      if (clientId == null) continue;
      final parsed = _fromDoc(uid, clientId, doc.id, data);
      if (parsed != null) movements.add(parsed);
      final stamp = data['updatedAt'];
      if (stamp is Timestamp) {
        final at = stamp.toDate().toUtc();
        if (cursor == null || at.isAfter(cursor)) cursor = at;
      }
    }
    return MovementChanges(movements: movements, cursor: cursor);
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
