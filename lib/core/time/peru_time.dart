/// Hora de Perú (America/Lima): UTC−5 todo el año, sin horario de verano.
const peruUtcOffset = Duration(hours: -5);

/// Instante del reloj mostrado en Perú, para textos y voz.
DateTime toPeru(DateTime instant) {
  return instant.toUtc().add(peruUtcOffset);
}

/// Ahora en Perú.
DateTime peruNow() => toPeru(DateTime.now());

/// Interpreta fecha/hora del reloj de Perú y la convierte a UTC para guardar.
DateTime fromPeruWallClock(DateTime wall) {
  return DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
  ).add(const Duration(hours: 5));
}

/// Lee un epoch (UTC) guardado en SQLite.
DateTime fromEpochMillis(int milliseconds) {
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

/// Día civil de Perú como YYYYMMDD. Sirve para pedidos “para el martes”.
int peruDateKey(DateTime instant) {
  final peru = toPeru(instant);
  return peru.year * 10000 + peru.month * 100 + peru.day;
}

int peruTodayDateKey([DateTime? now]) => peruDateKey(now ?? DateTime.now());

int peruTomorrowDateKey([DateTime? now]) {
  final peru = toPeru(now ?? DateTime.now());
  final tomorrow = DateTime.utc(
    peru.year,
    peru.month,
    peru.day,
  ).add(const Duration(days: 1));
  return tomorrow.year * 10000 + tomorrow.month * 100 + tomorrow.day;
}

int peruDateKeyFromYmd(int year, int month, int day) {
  return year * 10000 + month * 100 + day;
}

/// Medianoche de ese día en Perú, en UTC, para mostrar o comparar.
DateTime fromPeruDateKey(int key) {
  return fromPeruWallClock(
    DateTime(_yearOf(key), _monthOf(key), _dayOf(key)),
  );
}

/// Inicio inclusive y fin exclusivo de un día civil de Perú, en UTC.
({DateTime start, DateTime end}) peruDayBounds(int key) {
  final start = fromPeruDateKey(key);
  return (start: start, end: start.add(const Duration(days: 1)));
}

bool isValidPeruDateKey(int key) {
  final year = _yearOf(key);
  final month = _monthOf(key);
  final day = _dayOf(key);
  if (year < 2020 || year > 2100) return false;
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  final probe = DateTime.utc(year, month, day);
  return probe.year == year && probe.month == month && probe.day == day;
}

int _yearOf(int key) => key ~/ 10000;
int _monthOf(int key) => (key ~/ 100) % 100;
int _dayOf(int key) => key % 100;
