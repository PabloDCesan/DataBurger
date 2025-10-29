// lib/features/expenses/expenses_service.dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show DatabaseExecutor; // tipo correcto
import '../../core/xls_converter.dart';
//import 'package:flutter/foundation.dart' show kDebugMode;
//import 'package:flutter/material.dart' show debugPrint;
//const bool kLogExpensesParse = true; import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ExpenseRow {
  final int? id;
  final DateTime fecha;     // "YYYY-MM-DD"
  final String tipo;        // 'factura' | 'gastos' (o 'facturaA' | 'general')
  final String categoria;   // "Carne", "Plomeria", etc.
  final double monto;
  final String? nota;

  ExpenseRow({
    this.id,
    required this.fecha,
    required this.tipo,
    required this.categoria,
    required this.monto,
    this.nota,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'fecha': fecha.toIso8601String().substring(0, 10),
        'tipo': tipo,
        'categoria': categoria,
        'monto': monto,
        'nota': nota,
      };

  static ExpenseRow fromMap(Map<String, Object?> m) => ExpenseRow(
        id: m['id'] as int?,
        fecha: DateTime.parse((m['fecha'] as String).substring(0, 10)),
        tipo: m['tipo'] as String,
        categoria: m['categoria'] as String,
        monto: (m['monto'] as num).toDouble(),
        nota: m['nota'] as String?,
      );
}

class ExpensesImportResult {
  final int inserted;
  final int skipped;
  ExpensesImportResult(this.inserted, this.skipped);
}

class ExpensesService {
  final DatabaseExecutor db;
  ExpensesService(this.db);

  /// Tu tabla `expenses` ya la crea core/db.dart con:
  /// (id, fecha, categoria, monto, tipo, nota)
  /// Acá sólo garantizamos `expenses_uploads` e índices útiles.
  Future<void> ensureSchema() async {
    // 1) Asegurar la tabla principal (tu esquema real de db.dart)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        categoria TEXT NOT NULL,
        monto REAL NOT NULL,
        tipo TEXT,
        nota TEXT
      );
    ''');

    // 2) Índice único (depende de que la tabla YA exista)
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_unique
      ON expenses(fecha, tipo, categoria);
    ''');

    // 3) Tabla de uploads
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses_uploads(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT,
        month TEXT,                       -- 'YYYY-MM-01'
        inserted INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      );
    ''');
  }

  Future<DateTime?> lastUploadAt() async {
    final rows = await db.rawQuery(
      'SELECT created_at FROM expenses_uploads ORDER BY id DESC LIMIT 1',
    );
    if (rows.isEmpty || rows.first['created_at'] == null) return null;
    return DateTime.tryParse(rows.first['created_at'] as String);
  }

  Future<bool> hasPreviousMonthData(DateTime now) async {
    final prev = DateTime(now.year, now.month - 1, 1);
    final ym = '${prev.year.toString().padLeft(4, '0')}-${prev.month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM expenses WHERE substr(fecha,1,7)=?',
      [ym],
    );
    final c = (rows.first['c'] as num).toInt();
    return c > 0;
  }

  String _monthKey(DateTime dt) => DateTime(dt.year, dt.month, 1).toIso8601String();

  // ---- Importar desde archivo ----
  Future<ExpensesImportResult> importFromFile(
    String path, {
    String? fileName,
    DateTime? month,
  }) async {
    await ensureSchema();

    final file = File(path);
    if (!await file.exists()) {
      throw ArgumentError('Archivo no encontrado: $path');
    }

    final table = await convertAnyToTable(path);
    final parsed = _parseExpenses(table);

    // Mes destino (guardamos día = 1 para el mes)
    final now = DateTime.now();
    final monthDt = DateTime((month ?? now).year, (month ?? now).month, 1);

    int inserted = 0, skipped = 0;

    for (final r in parsed) {
      final fechaMes = DateTime(monthDt.year, monthDt.month, 1);
      try {
        await db.insert('expenses', {
          'fecha': fechaMes.toIso8601String().substring(0, 10),
          'tipo': r.tipo,
          'categoria': r.categoria,
          'monto': r.monto,
          'nota': r.nota,
        });
        inserted++;
      } catch (_) {
        // Conflicto por índice único -> actualizamos monto/nota
        await db.rawQuery(
          'UPDATE expenses SET monto=?, nota=? WHERE fecha=? AND tipo=? AND categoria=?',
          [
            r.monto,
            r.nota,
            fechaMes.toIso8601String().substring(0, 10),
            r.tipo,
            r.categoria,
          ],
        );
        skipped++;
      }
    }

    await db.insert('expenses_uploads', {
      'file_name': fileName ?? path.split(Platform.pathSeparator).last,
      'month': _monthKey(monthDt),
      'inserted': inserted,
      'skipped': skipped,
      'created_at': DateTime.now().toIso8601String(),
    });

    return ExpensesImportResult(inserted, skipped);
  }

  // Parser de la tabla usando marcadores "Factura..." / "Gastos" ... "Total"
  List<ExpenseRow> _parseExpenses(List<List<String>> table) {
    String? bloque; // 'factura' | 'gastos'
    final out = <ExpenseRow>[];
    final hoy = DateTime.now();
    final fechaMes = DateTime(hoy.year, hoy.month, 1);

    String norm(String s) => s.trim();
    String cleanMarker(String s) => s.toLowerCase().trim();

  /*
  double? parseMoneyOrNull(String s) {
    if (s.isEmpty) return null;

    // Limpieza: $ y todos los espacios (incluye NBSP/NNBSP)
    var t = s
        .replaceAll('\$', '')
        .replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');

    final lastDot   = t.lastIndexOf('.');
    final lastComma = t.lastIndexOf(',');

    if (lastDot >= 0 && lastComma >= 0) {
      // Hay ambos separadores: el ÚLTIMO define el decimal.
      if (lastComma > lastDot) {
        // Formato ES: 1.234,56  -> quitar puntos (miles), coma -> punto
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Formato EN: 1,234.56  -> quitar comas (miles), dejar punto decimal
        t = t.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      // Solo coma: tratar como decimal ES
      t = t.replaceAll('.', '');  // por si hubiera puntos “de miles” sueltos
      t = t.replaceAll(',', '.');
    } else {
      // Solo punto o sólo dígitos: dejar tal cual
    }

    return double.tryParse(t);
  }

  // compat: si querés mantener la vieja firma
  double parseMoney(String s) => parseMoneyOrNull(s) ?? 0.0;

  bool isNumericLike(String s) {
    if (!RegExp(r'\d').hasMatch(s)) return false; // al menos un dígito
    return parseMoneyOrNull(s) != null;
  }

  */

  
  double? parseMoneySmartOrNull(String s) {
    if (s.isEmpty) return null;

    // 1) Limpieza de moneda y espacios (incluye NBSP \u00A0, NNBSP \u202F)
    var t = s
        .replaceAll('\$', '')
        .replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');

    if (t.isEmpty || !RegExp(r'\d').hasMatch(t)) return null;

    final dotIdxs   = RegExp(r'\.').allMatches(t).map((m) => m.start).toList();
    final commaIdxs = RegExp(r',').allMatches(t).map((m) => m.start).toList();

    bool onlyCommas = commaIdxs.isNotEmpty && dotIdxs.isEmpty;
    bool onlyDots   = dotIdxs.isNotEmpty && commaIdxs.isEmpty;
    bool both       = commaIdxs.isNotEmpty && dotIdxs.isNotEmpty;

    // 2) Casos
    if (both) {
      // Hay ambos: el último separador que aparezca se toma como "decimal"
      final lastDot   = dotIdxs.isEmpty ? -1   : dotIdxs.last;
      final lastComma = commaIdxs.isEmpty ? -1 : commaIdxs.last;

      if (lastComma > lastDot) {
        // ...1.234,56  (ES): quitar puntos (miles), coma -> punto
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // ...1,234.56  (EN): quitar comas (miles), dejar punto
        t = t.replaceAll(',', '');
      }
      return double.tryParse(t);
    }

    if (onlyCommas) {
      // 1234,56  (ES)  o  1,234,567 (EN miles)
      final lastComma = commaIdxs.last;
      final after = t.substring(lastComma + 1);
      final looksThousands = commaIdxs.length > 1 || RegExp(r'^\d{3}$').hasMatch(after);
      t = looksThousands ? t.replaceAll(',', '') : t.replaceAll(',', '.');
      return double.tryParse(t);
    }

    if (onlyDots) {
    // 1234.56 (EN) o 1.234.567 (ES miles)
    final lastDot = dotIdxs.last;
    final after = t.substring(lastDot + 1);
    final looksThousands = dotIdxs.length > 1 || RegExp(r'^\d{3}$').hasMatch(after);
    t = looksThousands ? t.replaceAll('.', '') : t;
    return double.tryParse(t);
    }

    // Sin separadores, debería parsear directo
    return double.tryParse(t);
  }

  bool isNumericEs(String s) {
    if (!RegExp(r'\d').hasMatch(s)) return false;
    return parseMoneySmartOrNull(s) != null;
  }

  // Ajuste de escala (si tu fuente viene milificada, usá 1000.0; si no, 1.0)
  // const _scaleMultiplier = 1.0;

  // helper para redondear a 2 decimales y guardar como double “limpio”
  //double round2(double v) => double.parse(v.toStringAsFixed(2));

  for (int rowIdx = 0; rowIdx < table.length; rowIdx++) {
    final raw = table[rowIdx];
    // FIX dead code: e nunca es null (ya es String). Clonamos como List<String>.
    final line = List<String>.from(raw);
    // si TODAS las celdas están vacías (tras trim), saltamos
    if (line.every((s) => s.trim().isEmpty)) continue;

    // a = primer celda no vacía como “categoría/rótulo”
    final nonEmpty = line.where((e) => e.trim().isNotEmpty).toList();
    final a = nonEmpty.isNotEmpty ? norm(nonEmpty[0]) : '';
    final la = cleanMarker(a);

    // Marcadores explícitos
    if (la.startsWith('factura')) { 
      bloque = 'factura'; 
      continue; 
    }
    if (la == 'gastos') { 
      bloque = 'gastos';        
      continue; 
    }
    if (la == 'total') {       
      bloque = null;      
      continue; 
    }

  final b = (line.length > 1) ? line[1].trim() : '';

  // Heurística: arranque “factura” si aún no hay bloque y vemos texto + número
  if (bloque == null && a.isNotEmpty && (isNumericEs(b) || line.skip(1).any((s) => isNumericEs(s.trim())))) {
    bloque = 'factura';
  }
  if (bloque == null) continue;

  // Elegir importe: preferimos col 2; si no, la última numérica a la derecha
  String? amountStr;
  if (isNumericEs(b)) {
    amountStr = b;
  } else {
    for (int i = line.length - 1; i >= 1; i--) {
      final s = line[i].trim();
      if (isNumericEs(s)) { amountStr = s; break; }
    }
  }

  final parsed = amountStr != null ? parseMoneySmartOrNull(amountStr) : null;
  final categoria = a;

  // Ajuste/escala y redondeo (según lo que definiste)
  const scaleMultiplier = 1.0;                // tu elección actual
  double round2(double v) => double.parse(v.toStringAsFixed(2));
  final monto = (parsed == null) ? 0.0 : round2(parsed * scaleMultiplier);

  // Agregar fila (si querés reintroducir el filtro de 0, acá lo controlás)
  if (categoria.isNotEmpty) {
    out.add(ExpenseRow(
      fecha: fechaMes,
      tipo: bloque,
      categoria: categoria,
      monto: monto,
      nota: null,
    ));
  }
}
  return out;
}



  // ---- Consultas ----
  Future<List<ExpenseRow>> expensesForMonth(DateTime month) async {
    final ym = '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final res = await db.rawQuery(
      'SELECT id, fecha, tipo, categoria, monto, nota '
      'FROM expenses WHERE substr(fecha,1,7)=? ORDER BY tipo, categoria',
      [ym],
    );
    return res.map(ExpenseRow.fromMap).toList();
  }

  Future<Map<String, double>> totalsForMonth(DateTime month) async {
    final rows = await expensesForMonth(month);
    final byTipo = <String, double>{};
    for (final r in rows) {
      byTipo[r.tipo] = (byTipo[r.tipo] ?? 0) + r.monto;
    }
    final total = rows.fold<double>(0, (p, e) => p + e.monto);
    return {
      ...byTipo,
      'total': total,
    };
  }

  // ---- CRUD para "Editar gastos" ----
  Future<int> addExpense(ExpenseRow r) async {
    await ensureSchema();
    final id = await db.insert('expenses', {
      ...r.toMap()..remove('id'),
    });
    return id;
  }

  Future<void> updateExpense(ExpenseRow r) async {
    await ensureSchema();
    if (r.id == null) {
      throw ArgumentError('id requerido');
    }
    await db.rawQuery(
      'UPDATE expenses SET fecha=?, tipo=?, categoria=?, monto=?, nota=? WHERE id=?',
      [
        r.fecha.toIso8601String().substring(0, 10),
        r.tipo,
        r.categoria,
        r.monto,
        r.nota,
        r.id,
      ],
    );
  }

  Future<void> deleteExpense(int id) async {
    await ensureSchema();
    await db.rawQuery('DELETE FROM expenses WHERE id=?', [id]);
  }
}
