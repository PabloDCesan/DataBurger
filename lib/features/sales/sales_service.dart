import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/xls_converter.dart';
import '../../core/date_utils.dart';
import 'package:csv/csv.dart';

const _REQUIRED_HEADERS = [
  'Orden',
  'Orden Local',
  'ID Externo',
  'Establecimiento',
  'Marca',
  'Delivery',
  'Turno',
  'Canal',
  'Plano',
  'Apertura',
  'Cierre',
  'Tipo',
  'Pagos',
  'Total',
];

String _norm(String s) {
  // quitar comillas simples y dobles sin usar RegExp
  final noQuotes = s.replaceAll("'", '').replaceAll('"', '');
  // colapsar espacios y trim
  final oneSpace = noQuotes.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneSpace.toLowerCase();
}

bool _hasAllRequiredHeaders(List<String> headers) {
  final normHeaders = headers.map(_norm).toSet();
  for (final h in _REQUIRED_HEADERS) {
    if (!normHeaders.contains(_norm(h))) return false;
  }
  return true;
}

class SalesImportResult {
  final DateTime? rangeStart; // min Apertura
  final DateTime? rangeEnd;   // max Cierre
  final int insertedDays;
  final int skippedDays;
  final String? fileName;

  // NUEVO: totales del archivo
  final double ingresoRealTotal;
  final double ingresoTotalTotal;
  final double retiroAppsTotal;
  final int countPedidosYaTotal;
  final int countRappiTotal;
  
  SalesImportResult({
    required this.rangeStart,
    required this.rangeEnd,
    required this.insertedDays,
    required this.skippedDays,
    required this.fileName,
    required this.ingresoRealTotal,
    required this.ingresoTotalTotal,
    required this.retiroAppsTotal,
    required this.countPedidosYaTotal,
    required this.countRappiTotal,
  });
}

class SalesService {
  final Database db;
  SalesService(this.db);

  Future<SalesImportResult> importSalesFromFile(String path, {String? fileName}) async {

    // 1) normalizar a xlsx/csv
    final ext = p.extension(path).toLowerCase();
    String workPath = path;
    if (ext == '.xls') {
      workPath = await convertXlsToXlsxWindows(path); // lanza si falla
      fileName = '${p.basenameWithoutExtension(fileName ?? path)}.xlsx (convertido)';
    }

    // 2) obtener filas (lista de mapas por encabezado)
    final rows = await _readRows(workPath);

    // 3) proyectar columnas que nos interesan
    // Encabezados esperados:
    // "Orden","Orden Local","ID Externo","Establecimiento","Marca","Delivery",
    // "Turno","Canal","Plano","Apertura","Cierre","Tipo","Pagos","Total"
    
    final parsed = <_SalesRow>[];

    double sumPagos = 0, sumTotal = 0;
    int cPY = 0, cRP = 0;
    
    for (final r in rows) {
      final aperturaRaw = '${r['Apertura'] ?? ''}'.trim();
      final cierreRaw = '${r['Cierre'] ?? ''}'.trim();
      final canal = '${r['Canal'] ?? ''}'.trim().toLowerCase();
      final pagos = _toDouble(r['Pagos']);
      final total = _toDouble(r['Total']);

      final apertura = parseDdMmYyyyHhMm(aperturaRaw);
      final cierre = parseDdMmYyyyHhMm(cierreRaw);

      if (apertura == null || cierre == null) {
        // fila inválida, la saltamos
        continue;
      }
      
      sumPagos += pagos;
      sumTotal += total;
      if (canal == 'pedidos_ya') cPY++;
      if (canal == 'rappi') cRP++;

 
      parsed.add(_SalesRow(
        apertura: apertura,
        cierre: cierre,
        canal: canal,
        pagos: pagos,
        total: total,
      ));
    }
    final retiroAppsTotal = sumTotal - sumPagos;

    if (parsed.isEmpty) {
    // No hubo ni una fila con fechas válidas
    return SalesImportResult(
      rangeStart: null,
      rangeEnd: null,
      insertedDays: 0,
      skippedDays: 0,
      fileName: fileName ?? p.basename(path),
      ingresoRealTotal: 0,
      ingresoTotalTotal: 0,
      retiroAppsTotal: 0,
      countPedidosYaTotal: 0,
      countRappiTotal: 0,
    );
  }

    // 4) rango (min Apertura .. max Cierre)
    parsed.sort((a, b) => a.apertura.compareTo(b.apertura));
    final rangeStart = parsed.first.apertura;
    final rangeEnd = parsed.map((e) => e.cierre).reduce((a, b) => a.isAfter(b) ? a : b);

    // 5) group by day (yyyy-mm-dd) y acumular métricas
    final byDay = <String, _DayAgg>{};
    for (final r in parsed) {
      final dayKey = toIsoDay(r.apertura); // agrupamos por día de apertura
      final agg = byDay.putIfAbsent(dayKey, () => _DayAgg());
      agg.ingresoReal += r.pagos;
      agg.ingresoTotal += r.total;
      if (r.canal == 'pedidos_ya') agg.cPedidosYa += 1;
      if (r.canal == 'rappi') agg.cRappi += 1;
    }
    for (final d in byDay.values) {
      d.retiroApps = d.ingresoTotal - d.ingresoReal;
    }

    // 6) insertar solo días que NO existan (ignore duplicados)
    int inserted = 0;
    int skipped = 0;
    final nowIso = DateTime.now().toIso8601String();

    // Asegurarnos del modo "ignore" por PK ya existente
    await db.transaction((txn) async {
      for (final entry in byDay.entries) {
        final day = entry.key;
        final agg = entry.value;

        final existing = await txn.query(
          'daily_sales_summary',
          columns: ['day'],
          where: 'day = ?',
          whereArgs: [day],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          skipped++;
          continue;
        }

        await txn.insert('daily_sales_summary', {
          'day': day,
          'ingreso_real': agg.ingresoReal,
          'ingreso_total': agg.ingresoTotal,
          'retiro_apps': agg.retiroApps,
          'count_pedidosya': agg.cPedidosYa,
          'count_rappi': agg.cRappi,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
        inserted++;
      }

      // registrar el upload, aunque sea con 0 inserts
      await txn.insert('sales_uploads', {
        'file_name': fileName ?? p.basename(path),
        'range_start': toIsoMinute(rangeStart),
        'range_end': toIsoMinute(rangeEnd),
        'inserted_days': inserted,
        'skipped_days': skipped,
        'created_at': nowIso,
      });
    });

    return SalesImportResult(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      insertedDays: inserted,
      skippedDays: skipped,
      fileName: fileName ?? p.basename(path),
      ingresoRealTotal: sumPagos,
      ingresoTotalTotal: sumTotal,
      retiroAppsTotal: retiroAppsTotal,
      countPedidosYaTotal: cPY,
      countRappiTotal: cRP,
    );
  }

  // --- Helpers privados ---

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  Future<List<Map<String, dynamic>>> _readRows(String path) async {
    if (path.toLowerCase().endsWith('.xlsx')) {
      return _readRowsXlsx(path);
    } else if (path.toLowerCase().endsWith('.csv')) {
      return _readRowsCsv(path);
    } else {
      throw UnsupportedError('Formato no soportado: $path');
    }
  }

  Future<List<Map<String, dynamic>>> _readRowsXlsx(String path) async {
      try {
      final bytes = await File(path).readAsBytes();
      final book = xls.Excel.decodeBytes(bytes);
      if (book.tables.isEmpty) return [];
      final table = book.tables.values.first;

      // encabezados en fila 0
      final headersRaw = table.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
      if (!_hasAllRequiredHeaders(headersRaw)) {
        // devolvemos cuáles faltan para debug:
        final have = headersRaw.map(_norm).toSet();
        final missing = _REQUIRED_HEADERS.where((r) => !have.contains(_norm(r))).toList();
        throw FormatException('Faltan columnas: ${missing.join(', ')}');
      }

      final rows = <Map<String, dynamic>>[];
      for (var r = 1; r < table.maxRows; r++) {
        final rowCells = table.row(r);
        final isEmpty = rowCells.every((c) => (c?.value == null || c!.value.toString().trim().isEmpty));
        if (isEmpty) continue;

        final map = <String, dynamic>{};
        for (var i = 0; i < headersRaw.length && i < rowCells.length; i++) {
          final h = headersRaw[i];
          if (h.isEmpty) continue;
          map[h] = rowCells[i]?.value;
        }
        rows.add(map);
      }
      return rows;
      } catch (_) {
      // Fallback robusto: si Excel package falla (numFmtId, etc.), convertimos a CSV con PowerShell y leemos CSV
      final csvPath = await convertXlsxToCsvWindows(path);
      return await _readRowsCsv(csvPath);
    }
  }

  Future<List<Map<String, dynamic>>> _readRowsCsv(String path) async {
    final content = await File(path).readAsString();
    final csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csv.isEmpty) return [];

    final headersRaw = csv.first.map((e) => e.toString().trim()).toList();
    if (!_hasAllRequiredHeaders(headersRaw)) {
      final have = headersRaw.map(_norm).toSet();
      final missing = _REQUIRED_HEADERS.where((r) => !have.contains(_norm(r))).toList();
      throw FormatException('Faltan columnas: ${missing.join(', ')}');
    }

    final rows = <Map<String, dynamic>>[];
    for (var r = 1; r < csv.length; r++) {
      final parts = csv[r].map((e) => e?.toString() ?? '').toList();
      final isEmpty = parts.every((s) => s.trim().isEmpty);
      if (isEmpty) continue;

      final map = <String, dynamic>{};
      for (var i = 0; i < headersRaw.length && i < parts.length; i++) {
        final h = headersRaw[i];
        if (h.isEmpty) continue;
        map[h] = parts[i].trim();
      }
      rows.add(map);
    }
    return rows;
  }
}

class _SalesRow {
  final DateTime apertura;
  final DateTime cierre;
  final String canal;
  final double pagos;
  final double total;
  _SalesRow({
    required this.apertura,
    required this.cierre,
    required this.canal,
    required this.pagos,
    required this.total,
  });
}

class _DayAgg {
  double ingresoReal = 0;
  double ingresoTotal = 0;
  double retiroApps = 0;
  int cPedidosYa = 0;
  int cRappi = 0;
}

extension SalesQueries on SalesService {
  Future<DateTime?> lastUploadAt() async {
    final rows = await db.rawQuery('SELECT created_at FROM sales_uploads ORDER BY id DESC LIMIT 1');
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['created_at'] as String);
  }

  Future<List<Map<String, Object?>>> summaryForMonth(DateTime month) async {
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final from = '${first.year.toString().padLeft(4,'0')}-${first.month.toString().padLeft(2,'0')}-01';
    final to = '${next.year.toString().padLeft(4,'0')}-${next.month.toString().padLeft(2,'0')}-01';

    return db.rawQuery('''
      SELECT day, ingreso_real, ingreso_total, retiro_apps, count_pedidosya, count_rappi
      FROM daily_sales_summary
      WHERE day >= ? AND day < ?
      ORDER BY day ASC
    ''', [from, to]);
  }

  Future<bool> hasPreviousMonthData(DateTime ref) async {
    final prev = DateTime(ref.year, ref.month - 1, 1);
    final rows = await summaryForMonth(prev);
    return rows.isNotEmpty;
  }
}
