import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/error/client_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/client/data/datasources/client_remote_datasource.dart';
import 'package:dale_u/features/client/domain/entities/client.dart';
import 'package:dale_u/features/client/domain/invite_code.dart';

/// Escribe en vendors/{uid}/clients e invites/{code}.
class FirestoreClientRemoteDataSource implements ClientRemoteDataSource {
  FirestoreClientRemoteDataSource({
    FirebaseFirestore? firestore,
    this.vendorNameOf,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  /// Nombre del vendedor para que el comprador vea a quién le debe.
  final String Function()? vendorNameOf;
  static const _timeout = Duration(seconds: 20);

  CollectionReference<Map<String, dynamic>> _col(String vendorUid) {
    return firestore.collection('vendors').doc(vendorUid).collection('clients');
  }

  @override
  Future<void> upsert(Client client) async {
    final vendorUid = InputSanitizer.uid(client.vendorUid);
    final clientId = InputSanitizer.uid(client.id);
    final name = InputSanitizer.personName(client.name);
    final invite = InviteCode.parse(client.inviteCode);
    if (vendorUid == null || clientId == null || name == null || invite == null) {
      throw const ClientException('Cliente inválido para sincronizar.');
    }
    // `linkedUid` lo escribe solo el comprador al vincularse. El vendedor
    // nunca lo manda: antes, subir una ficha editada con la copia local
    // vieja borraba la vinculación y dejaba el código libre para otro.
    // `balanceCents` lo escribe la Cloud Function. Por eso se fusiona
    // (merge) en vez de reemplazar el documento.
    final batch = firestore.batch();
    final payload = <String, Object>{
      'vendorUid': vendorUid,
      'name': name,
      'phone': InputSanitizer.phone(client.phone),
      'createdAt': client.createdAt.millisecondsSinceEpoch,
      'updatedAt': client.updatedAt.millisecondsSinceEpoch,
      'active': client.active,
      'inviteCode': invite,
    };
    if (client.hasHousePin) {
      payload['latitude'] = client.latitude!;
      payload['longitude'] = client.longitude!;
    } else {
      payload['latitude'] = FieldValue.delete();
      payload['longitude'] = FieldValue.delete();
    }
    batch.set(
      _col(vendorUid).doc(clientId),
      payload,
      SetOptions(merge: true),
    );
    batch.set(
      firestore.collection('invites').doc(invite),
      {
        'vendorUid': vendorUid,
        'clientId': clientId,
        'active': client.active,
        'vendorName': _vendorName(),
      },
      SetOptions(merge: true),
    );
    await batch.commit().timeout(_timeout);
  }

  @override
  Future<List<Client>> fetchByVendor(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return const [];

    final snapshot = await _col(uid).get().timeout(_timeout);
    final clients = <Client>[];
    for (final doc in snapshot.docs) {
      final parsed = _fromDoc(uid, doc.id, doc.data());
      if (parsed != null) clients.add(parsed);
    }
    return clients;
  }

  Client? _fromDoc(String vendorUid, String id, Map<String, dynamic> data) {
    final safeId = InputSanitizer.uid(id);
    final name = InputSanitizer.personName(data['name'] as String?);
    if (safeId == null || name == null) return null;
    final createdAt = _asMillis(data['createdAt']);
    final updatedAt = _asMillis(data['updatedAt']);
    if (createdAt == null || updatedAt == null) return null;
    final invite = InviteCode.parse(data['inviteCode'] as String?);
    final lat = InputSanitizer.latitude(_asDouble(data['latitude']));
    final lng = InputSanitizer.longitude(_asDouble(data['longitude']));
    final hasHouse = lat != null && lng != null;
    return Client(
      id: safeId,
      vendorUid: vendorUid,
      name: name,
      phone: InputSanitizer.phone(data['phone'] as String?),
      createdAt: fromEpochMillis(createdAt),
      updatedAt: fromEpochMillis(updatedAt),
      pendingSync: invite == null,
      active: data['active'] != false,
      inviteCode: invite ?? InviteCode.generate(),
      linkedUid: InputSanitizer.uid(data['linkedUid'] as String?) ?? '',
      latitude: hasHouse ? lat : null,
      longitude: hasHouse ? lng : null,
    );
  }

  @override
  Future<void> publishVendorName(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    final name = _vendorName();
    if (uid == null || name.isEmpty) return;
    await firestore.collection('vendors').doc(uid).set({
      'displayName': name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }).timeout(_timeout);
  }

  @override
  Future<void> deleteCascade({
    required String vendorUid,
    required String clientId,
    required String inviteCode,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) {
      throw const ClientException('Cliente inválido.');
    }
    final movements = await _col(uid)
        .doc(id)
        .collection('movements')
        .get()
        .timeout(_timeout);
    var batch = firestore.batch();
    var ops = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit().timeout(_timeout);
      batch = firestore.batch();
      ops = 0;
    }

    for (final doc in movements.docs) {
      batch.delete(doc.reference);
      ops++;
      if (ops >= 400) await flush();
    }
    final invite = InviteCode.parse(inviteCode);
    if (invite != null) {
      batch.delete(firestore.collection('invites').doc(invite));
      ops++;
    }
    batch.delete(_col(uid).doc(id));
    ops++;
    await flush();
  }

  String _vendorName() {
    final raw = vendorNameOf?.call() ?? '';
    if (raw.trim().isEmpty) return '';
    return InputSanitizer.displayName(raw);
  }

  int? _asMillis(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return null;
  }
}
