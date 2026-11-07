import 'package:dale_u/core/database/app_database.dart';
import 'package:dale_u/core/error/order_exception.dart';
import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/orders/domain/entities/pan_order.dart';
import 'package:uuid/uuid.dart';

class PanOrderLocalDataSource {
  PanOrderLocalDataSource(this.database, {this.uuid = const Uuid()});

  final AppDatabase database;
  final Uuid uuid;

  Future<List<PanOrder>> listPending(String vendorUid) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null) return const [];
    final rows = await database.db.query(
      'pan_orders',
      where: 'vendor_uid = ?',
      whereArgs: [uid],
      orderBy: 'delivery_date ASC, created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<PanOrder> insert({
    required String vendorUid,
    required String label,
    required int deliveryDateKey,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final text = _labelOf(label);
    if (uid == null) {
      throw const OrderException('Sesión inválida.');
    }
    if (text == null) {
      throw const OrderException('Escribe qué te pidieron.');
    }
    if (!isValidPeruDateKey(deliveryDateKey)) {
      throw const OrderException('La fecha del pedido no es válida.');
    }
    final order = PanOrder(
      id: uuid.v4(),
      vendorUid: uid,
      label: text,
      deliveryDateKey: deliveryDateKey,
      createdAt: DateTime.now().toUtc(),
    );
    await database.db.insert('pan_orders', _toRow(order));
    return order;
  }

  /// Entregado: se borra. No queda rastro a propósito.
  Future<void> complete({
    required String vendorUid,
    required String id,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final orderId = InputSanitizer.uid(id);
    if (uid == null || orderId == null) {
      throw const OrderException('No se encontró el pedido.');
    }
    final count = await database.db.delete(
      'pan_orders',
      where: 'id = ? AND vendor_uid = ?',
      whereArgs: [orderId, uid],
    );
    if (count == 0) {
      throw const OrderException('No se encontró el pedido.');
    }
  }

  Future<void> deleteByClient({
    required String vendorUid,
    required String clientId,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    final id = InputSanitizer.uid(clientId);
    if (uid == null || id == null) return;
    await database.db.delete(
      'pan_orders',
      where: 'vendor_uid = ? AND client_id = ?',
      whereArgs: [uid, id],
    );
  }

  static String? _labelOf(String? raw) {
    final cleaned = InputSanitizer.spokenText(raw);
    if (cleaned.length < 2) return null;
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  Map<String, Object?> _toRow(PanOrder order) {
    return {
      'id': order.id,
      'vendor_uid': order.vendorUid,
      'client_id': '',
      'client_name': order.label,
      'delivery_date': order.deliveryDateKey,
      'note': '',
      'created_at': order.createdAt.millisecondsSinceEpoch,
    };
  }

  PanOrder _fromRow(Map<String, Object?> row) {
    final name = (row['client_name'] as String?) ?? '';
    final note = (row['note'] as String?) ?? '';
    final label = name.trim().isNotEmpty ? name : note;
    return PanOrder(
      id: row['id']! as String,
      vendorUid: row['vendor_uid']! as String,
      label: label,
      deliveryDateKey: row['delivery_date']! as int,
      createdAt: fromEpochMillis(row['created_at']! as int),
    );
  }
}
