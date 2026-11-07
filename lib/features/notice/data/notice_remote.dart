import 'package:dale_u/features/notice/domain/vendor_notice.dart';

abstract class NoticeRemote {
  Future<void> sendToBuyers({
    required String vendorUid,
    required String vendorName,
    required String body,
    required List<String> buyerUids,
  });

  Stream<List<VendorNotice>> watchBuyer(String buyerUid);

  /// El comprador ya lo leyó: se borra. No se archiva.
  Future<void> markSeen({
    required String buyerUid,
    required String vendorUid,
  });
}
