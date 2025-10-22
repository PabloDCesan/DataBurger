DateTime? parseDdMmYyyyHhMm(String raw) {
  // Espera "dd.mm.aaaa hh:mm"
  if (raw.isEmpty) return null;
  final parts = raw.trim().split(' ');
  if (parts.length < 2) return null;

  final dmy = parts[0].split('.');
  if (dmy.length != 3) return null;
  final time = parts[1].split(':');
  if (time.length != 2) return null;

  final dd = int.tryParse(dmy[0]);
  final mm = int.tryParse(dmy[1]);
  final yyyy = int.tryParse(dmy[2]);
  final hh = int.tryParse(time[0]);
  final min = int.tryParse(time[1]);

  if ([dd, mm, yyyy, hh, min].any((v) => v == null)) return null;

  return DateTime(yyyy!, mm!, dd!, hh!, min!);
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
