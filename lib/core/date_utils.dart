DateTime? parseDdMmYyyyHhMm(String raw) {
  if (raw.isEmpty) return null;
  final s = raw.trim().replaceAll('\u00A0', ' '); // NBSP -> espacio

  // Aceptar separadores variados: ".", "/", "-" entre día/mes/año y ":" en hora
  final re = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})\s+(\d{1,2}):(\d{2})$');
  final m = re.firstMatch(s);
  if (m == null) return null;

  final dd = int.parse(m.group(1)!);
  final mm = int.parse(m.group(2)!);
  final yyyy = int.parse(m.group(3)!);
  final hh = int.parse(m.group(4)!);
  final min = int.parse(m.group(5)!);

  if (dd < 1 || dd > 31 || mm < 1 || mm > 12 || hh < 0 || hh > 23 || min < 0 || min > 59) {
    return null;
  }
  return DateTime(yyyy, mm, dd, hh, min);
}

String toIsoMinute(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

String toIsoDay(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';
