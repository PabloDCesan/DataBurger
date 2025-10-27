import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/db_provider.dart';
import '../../sales/sales_service.dart';
import '../../../widgets/app_alerts.dart';
import '../../../core/export_service.dart';
import '../widgets/dialogs/sales_daily_table.dart';
import '../widgets/dialogs/sales_totals_table.dart';

class ModifySalesScreen extends ConsumerStatefulWidget {
  final bool isAdmin;
  const ModifySalesScreen({super.key, required this.isAdmin});

  @override
  ConsumerState<ModifySalesScreen> createState() => _ModifySalesScreenState();
}

class _ModifySalesScreenState extends ConsumerState<ModifySalesScreen> {
  String? _pickedPath;
  String? _fileName;
  DateTime? _lastUpload;
  bool _prevMonthAvailable = false;

  @override
  void initState() {
    super.initState();
    _refreshMeta();
  }

  Future<void> _refreshMeta() async {
    final svc = SalesService(ref.read(databaseProvider));
    _lastUpload = await svc.lastUploadAt();
    _prevMonthAvailable = await svc.hasPreviousMonthData(DateTime.now());
    if (mounted) setState(() {});
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    setState(() { _pickedPath = f.path; _fileName = f.name; });
  }

  Future<void> _importToDb() async {
    if (_pickedPath == null) {
      showError(context, 'Primero elegí un archivo.');
      return;
    }
    final svc = SalesService(ref.read(databaseProvider));
    try {
      final res = await svc.importSalesFromFile(_pickedPath!, fileName: _fileName);
      showSuccess(context,
        'Carga realizada.\n'
        'Días nuevos: ${res.insertedDays}, ignorados: ${res.skippedDays}\n'
        'Ingreso Real: ${res.ingresoRealTotal.toStringAsFixed(2)} / '
        'Total: ${res.ingresoTotalTotal.toStringAsFixed(2)} / '
        'Retiros: ${res.retiroAppsTotal.toStringAsFixed(2)}'
      );
      await _refreshMeta();
    } on FormatException catch (e) {
      showError(context, 'Encabezados inválidos: ${e.message}');
    } catch (e) {
      showError(context, 'Problema en la carga: $e');
    }
  }

  String _formatLastUpload(DateTime? dt) {
    if (dt == null) return '—';
    const meses = ['', 'enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
    final dd = dt.day.toString().padLeft(2,'0');
    final mes = meses[dt.month];
    final hh = dt.hour.toString().padLeft(2,'0');
    final mm = dt.minute.toString().padLeft(2,'0');
    return '$dd de $mes a las $hh:$mm';
  }

  Future<void> _showDaily(DateTime month, String title) async {
    final svc = SalesService(ref.read(databaseProvider));
    final rows = await svc.summaryForMonth(month);
    showDialog(context: context, builder: (_) => SalesDailyTable(title: title, rows: rows));
  }

  Future<void> _showTotals(DateTime month, String title) async {
    final svc = SalesService(ref.read(databaseProvider));
    final totals = await svc.summaryMonthTotals(month);
    showDialog(context: context, builder: (_) => SalesTotalsTable(title: title, totals: totals));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar Ventas'),
        actions: [
          if (widget.isAdmin) ...[
            IconButton(
              tooltip: 'Exportar (CSV)',
              icon: const Icon(Icons.download),
              onPressed: () async {
                try {
                  final db = ref.read(databaseProvider);
                  final path = await exportDailySalesCsv(db, month: now);
                  showSuccess(context, 'Exportado a:\n$path');
                } catch (e) {
                  showError(context, 'No se pudo exportar: $e');
                }
              },
            ),
            IconButton(
              tooltip: 'Reset DB',
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reiniciar base de datos'),
                    content: const Text('Esto eliminará todos los datos locales. ¿Continuar?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reiniciar')),
                    ],
                  ),
                ) ?? false;
                if (!ok) return;

                try {
                  final db = ref.read(databaseProvider);
                  await db.execute('DROP TABLE IF EXISTS daily_sales_summary;');
                  await db.execute('DROP TABLE IF EXISTS sales_uploads;');
                  await db.execute('''
                    CREATE TABLE IF NOT EXISTS daily_sales_summary(
                      day TEXT PRIMARY KEY,
                      ingreso_real REAL NOT NULL DEFAULT 0,
                      ingreso_total REAL NOT NULL DEFAULT 0,
                      retiro_apps REAL NOT NULL DEFAULT 0,
                      count_pedidosya INTEGER NOT NULL DEFAULT 0,
                      count_rappi INTEGER NOT NULL DEFAULT 0,
                      created_at TEXT,
                      updated_at TEXT
                    );
                  ''');
                  await db.execute('''
                    CREATE TABLE IF NOT EXISTS sales_uploads(
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      file_name TEXT,
                      range_start TEXT,
                      range_end TEXT,
                      inserted_days INTEGER NOT NULL DEFAULT 0,
                      skipped_days INTEGER NOT NULL DEFAULT 0,
                      created_at TEXT
                    );
                  ''');
                  await _refreshMeta();
                  showSuccess(context, 'Base reiniciada');
                } catch (e) {
                  showError(context, 'No se pudo reiniciar: $e');
                }
              },
            ),
          ],
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila archivo + última actualización
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Elegir archivo (.xlsx / .xls / .csv)'),
                ),
                const SizedBox(width: 16),
                Text('Última actualización: ${_formatLastUpload(_lastUpload)}'),
              ],
            ),
            const SizedBox(height: 16),

            // Importar + nombre archivo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: (_pickedPath != null) ? _importToDb : null,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Importar / Guardar'),
                ),
                if (_fileName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Opacity(opacity: .8, child: Text('Archivo seleccionado: $_fileName')),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Estado actual
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: () => _showTotals(now, 'Estado actual (totales del mes)'),
                             child: const Text('Ver estado actual')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => _showDaily(now, 'Estado actual (diario)'),
                             child: const Text('Ver estado actual - Diario')),
              ],
            ),
            const SizedBox(height: 16),

            // Mes anterior
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: _prevMonthAvailable ? () => _showTotals(prev, 'Estado mes anterior (totales)') : null,
                  child: const Text('Ver mes anterior'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _prevMonthAvailable ? () => _showDaily(prev, 'Estado mes anterior (diario)') : null,
                  child: const Text('Ver mes anterior - Diario'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
