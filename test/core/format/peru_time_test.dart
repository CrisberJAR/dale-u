import 'package:dale_u/core/format/money.dart';
import 'package:dale_u/core/time/peru_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el sello de hora usa Perú (UTC−5), no UTC', () {
    final utc = DateTime.utc(2026, 8, 30, 1, 19);
    expect(spokenStamp(utc), '29 de agosto a las 20:19');
    expect(fromPeruWallClock(DateTime(2026, 8, 29, 20, 19)).toUtc(), utc);
  });

  test('la clave de día usa el calendario de Perú', () {
    expect(peruDateKey(DateTime.utc(2026, 8, 31, 4)), 20260830);
    expect(peruTomorrowDateKey(DateTime.utc(2026, 8, 31, 12)), 20260901);
    expect(isValidPeruDateKey(20260231), isFalse);
    expect(isValidPeruDateKey(20260831), isTrue);
    final bounds = peruDayBounds(20260830);
    expect(bounds.start.toUtc(), DateTime.utc(2026, 8, 30, 5));
    expect(bounds.end.toUtc(), DateTime.utc(2026, 8, 31, 5));
  });
}
