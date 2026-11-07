import 'package:dale_u/core/security/input_sanitizer.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:dale_u/features/ledger/domain/entities/daily_close.dart';
import 'package:dale_u/features/ledger/domain/repositories/movement_repository.dart';

class ListDayMovements {
  const ListDayMovements(this._repository);

  final MovementRepository _repository;

  Future<DailyClose> call({
    required String vendorUid,
    required int dateKey,
  }) async {
    final uid = InputSanitizer.uid(vendorUid);
    if (uid == null || !isValidPeruDateKey(dateKey)) {
      return DailyClose.fromMovements(dateKey: dateKey, movements: const []);
    }
    final bounds = peruDayBounds(dateKey);
    final movements = await _repository.listByDay(
      vendorUid: uid,
      start: bounds.start,
      end: bounds.end,
    );
    return DailyClose.fromMovements(dateKey: dateKey, movements: movements);
  }
}
