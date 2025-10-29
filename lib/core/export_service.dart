// lib/core/export_service.dart
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../features/expenses/expenses_service.dart';


Future<String> _downloadsOrTemp() async {
  try {
    final dir = await getDownloadsDirectory(); // desktop
    if (dir != null) return dir.path;
  } catch (_) {}
  final tmp = await getTemporaryDirectory();
  return tmp.path;
}

String _yyyyMm(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Exporta DAILY_SALES_SUMMARY del mes a CSV (muchas filas)
Future<String> exportDailySalesCsv(Database db, {required DateTime month}) async {
  final first = DateTime(month.year, month.month, 1);
  final next  = DateTime(month.year, month.month + 1, 1);
  final from  = '${first.year.toString().padLeft(4,'0')}-${first.month.toString().padLeft(2,'0')}-01';
  final to    = '${next.year.toString().padLeft(4,'0')}-${next.month.toString().padLeft(2,'0')}-01';

  final rows = await db.rawQuery('''
    SELECT day, ingreso_real, ingreso_total, retiro_apps, count_pedidosya, count_rappi
    FROM daily_sales_summary
    WHERE day >= ? AND day < ?
    ORDER BY day ASC
  ''', [from, to]);

  final data = <List<dynamic>>[
    ['Día','Ingreso Real','Ingreso Total','Retiros Apps','PedidosYa','Rappi'],
    for (final r in rows)
      [
        r['day'] ?? '',
        r['ingreso_real'] ?? 0,
        r['ingreso_total'] ?? 0,
        r['retiro_apps'] ?? 0,
        r['count_pedidosya'] ?? 0,
        r['count_rappi'] ?? 0,
      ],
  ];

  final csv = const ListToCsvConverter().convert(data);
  final outDir = await _downloadsOrTemp();
  final outPath = p.join(outDir, 'databurger_ventas_diario_${_yyyyMm(first)}.csv');
  await File(outPath).writeAsString(csv);
  return outPath;
}

/// Exporta una SOLA FILA con TOTALES del mes a CSV
Future<String> exportSalesTotalsCsv(Database db, {required DateTime month}) async {
  final first = DateTime(month.year, month.month, 1);
  final next  = DateTime(month.year, month.month + 1, 1);
  final from  = '${first.year.toString().padLeft(4,'0')}-${first.month.toString().padLeft(2,'0')}-01';
  final to    = '${next.year.toString().padLeft(4,'0')}-${next.month.toString().padLeft(2,'0')}-01';

  final rows = await db.rawQuery('''
    SELECT
      MIN(day)  AS first_day,
      MAX(day)  AS last_day,
      SUM(ingreso_real)   AS ingreso_real,
      SUM(ingreso_total)  AS ingreso_total,
      SUM(retiro_apps)    AS retiro_apps,
      SUM(count_pedidosya) AS count_pedidosya,
      SUM(count_rappi)     AS count_rappi
    FROM daily_sales_summary
    WHERE day >= ? AND day < ?
  ''', [from, to]);

  final r = rows.isNotEmpty ? rows.first : <String, Object?>{};
  final data = <List<dynamic>>[
    ['Primer carga', 'Última carga', 'Ingreso Real', 'Ingreso Total', 'Retiros Apps', 'PedidosYa', 'Rappi'],
    [
      r['first_day'] ?? '',
      r['last_day'] ?? '',
      r['ingreso_real'] ?? 0,
      r['ingreso_total'] ?? 0,
      r['retiro_apps'] ?? 0,
      r['count_pedidosya'] ?? 0,
      r['count_rappi'] ?? 0,
    ],
  ];

  final csv = const ListToCsvConverter().convert(data);
  final outDir = await _downloadsOrTemp();
  final outPath = p.join(outDir, 'databurger_ventas_totales_${_yyyyMm(first)}.csv');
  await File(outPath).writeAsString(csv);
  return outPath;
}

Future<String> exportExpensesCsv(DatabaseExecutor db, {required DateTime month}) async {
  final svc = ExpensesService(db);
  final rows = await svc.expensesForMonth(month);

  final dir = await _downloadsOrTemp();
  final name = 'expenses_${month.year}-${month.month.toString().padLeft(2, '0')}.csv';
  final file = File(p.join(dir, name));
  final sink = file.openWrite();

  // Encabezados nuevos
  sink.writeln('fecha,tipo,categoria,monto,nota');

  for (final r in rows) {
    final fecha = r.fecha.toIso8601String().substring(0, 10);
    final tipo = r.tipo;
    // Escapar comillas si las hubiera en categoría/nota
    final categoria = '"${r.categoria.replaceAll('"', '""')}"';
    final nota = r.nota == null ? '' : '"${r.nota!.replaceAll('"', '""')}"';
    // Monto en notación estándar (punto decimal)
    final monto = r.monto.toStringAsFixed(2);

    sink.writeln('$fecha,$tipo,$categoria,$monto,$nota');
  }

  await sink.flush();
  await sink.close();
  return file.path;
}