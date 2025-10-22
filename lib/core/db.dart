import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDb {
  static final AppDb _instance = AppDb._internal();
  factory AppDb() => _instance;
  AppDb._internal();

  late Database _db;
  bool _opened = false;

  Database get db => _db;

  Future<void> open() async {
    if (_opened) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'databurger.sqlite');

    _db = await databaseFactory.openDatabase(dbPath);
    await _migrate();
    _opened = true;
  }

  Future<void> _migrate() async {
    // versión inicial (1)
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        is_admin INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        failed_attempts INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS stock_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        precio_promedio REAL NOT NULL DEFAULT 0,
        puntos INTEGER
      );
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS stock_ledger(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        tipo TEXT NOT NULL, -- inicial, adicional, venta, desperdicio, ajuste
        cantidad REAL NOT NULL,
        fecha TEXT NOT NULL,
        nota TEXT,
        FOREIGN KEY(item_id) REFERENCES stock_items(id)
      );
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        canal TEXT,
        total REAL NOT NULL,
        pagos TEXT,
        turno TEXT,
        delivery INTEGER,
        marca TEXT,
        establecimiento TEXT
      );
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fecha TEXT NOT NULL,
        categoria TEXT NOT NULL,
        monto REAL NOT NULL,
        tipo TEXT, -- facturaA | general
        nota TEXT
      );
    ''');

    await _db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_closures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mes TEXT NOT NULL,        -- "2025-10"
        ingresos_total REAL NOT NULL,
        gastos_total REAL NOT NULL,
        ganancia_neta REAL NOT NULL,
        snapshot_json TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    // Días consolidados de ventas (1 fila por día, evita duplicados)
await _db.execute('''
  CREATE TABLE IF NOT EXISTS daily_sales_summary(
    day TEXT PRIMARY KEY,             -- "YYYY-MM-DD"
    ingreso_real REAL NOT NULL,       -- suma Pagos
    ingreso_total REAL NOT NULL,      -- suma Total
    retiro_apps REAL NOT NULL,        -- ingreso_total - ingreso_real
    count_pedidosya INTEGER NOT NULL, -- cantidad "pedidos_ya" en Canal
    count_rappi INTEGER NOT NULL,     -- cantidad "rappi" en Canal
    created_at TEXT NOT NULL,         -- cuándo se insertó
    updated_at TEXT NOT NULL          -- última vez que se tocó
  );
''');

// Registro de uploads (para auditoría / última actualización / rango)
await _db.execute('''
  CREATE TABLE IF NOT EXISTS sales_uploads(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name TEXT,
    range_start TEXT NOT NULL,        -- "YYYY-MM-DD HH:MM"
    range_end TEXT NOT NULL,          -- "YYYY-MM-DD HH:MM"
    inserted_days INTEGER NOT NULL,   -- cuántos días nuevos metimos
    skipped_days INTEGER NOT NULL,    -- cuántos días ya existían (ignorados)
    created_at TEXT NOT NULL
  );
''');

  }
}
