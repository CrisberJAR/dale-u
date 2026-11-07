import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dale_u/core/error/presence_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/features/presence/data/datasources/presence_remote_datasource.dart';
import 'package:dale_u/features/presence/domain/vendor_presence.dart';

class FirestorePresenceRemoteDataSource implements PresenceRemoteDataSource {
  FirestorePresenceRemoteDataSource({FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;
  static const _timeout = Duration(seconds: 20);

  @override
  Future<void> publish(String vendorUid, VendorPresence presence) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) {
      throw const PresenceException('Sesión inválida. Vuelve a entrar.');
    }
    final payload = <String, Object>{
      'onRoute': presence.onRoute,
      'updatedAt': presence.updatedAt.millisecondsSinceEpoch,
    };
    final fix = presence.fix;
    if (presence.onRoute && fix != null) {
      final lat = InputSanitizer.latitude(fix.latitude);
      final lng = InputSanitizer.longitude(fix.longitude);
      if (lat == null || lng == null) {
        throw const PresenceException('Esa ubicación no es válida.');
      }
      payload['latitude'] = lat;
      payload['longitude'] = lng;
    }
    try {
      await firestore
          .collection('vendors')
          .doc(uid)
          .collection('presence')
          .doc('current')
          .set(payload)
          .timeout(_timeout);
    } on FirebaseException catch (error) {
      throw PresenceException(_map(error));
    }
  }

  @override
  Future<VendorPresence?> fetch(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return null;
    try {
      final snapshot = await _doc(uid).get().timeout(_timeout);
      return VendorPresence.tryParse(snapshot.data());
    } on FirebaseException catch (error) {
      throw PresenceException(_mapRead(error));
    }
  }

  @override
  Stream<VendorPresence?> watch(String vendorUid) {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return Stream<VendorPresence?>.value(null);
    return _doc(uid).snapshots().map((snapshot) {
      return VendorPresence.tryParse(snapshot.data());
    });
  }

  DocumentReference<Map<String, dynamic>> _doc(String vendorUid) {
    return firestore
        .collection('vendors')
        .doc(vendorUid)
        .collection('presence')
        .doc('current');
  }

  String _mapRead(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'No puedes ver esa ubicación. ¿Sigues vinculado?';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sin señal para ver al panadero.';
      default:
        return 'No se pudo leer la ubicación (${error.code}).';
    }
  }

  String _map(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firebase no dejó publicar la ubicación. Revisa las reglas.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Sin señal. Se intentará de nuevo en un momento.';
      default:
        return 'No se pudo subir la ubicación (${error.code}).';
    }
  }
}
