import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db_provider.dart';
import '../../../widgets/app_alerts.dart';
import '../../../core/export_service.dart';
import '../../expenses/expenses_service.dart';
import 'edit_expenses_screen.dart';
import '../../auth/auth_controller.dart';
import '../../../core/money_format.dart';

class ConfigExpensesScreen extends ConsumerStatefulWidget {
  const ConfigExpensesScreen({super.key});
  @override
  ConsumerState<ConfigExpensesScreen> createState() => _ConfigExpensesScreenState();
}

class _ConfigExpensesScreenState extends ConsumerState<ConfigExpensesScreen> {
  String? _pickedPath;
  String? _fileName;
  DateTime? _lastUpload;
  bool _prevMonthAvailable = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _refreshMeta();
  }

  

  Future<void> _refreshMeta() async {
    final svc = ExpensesService(ref.read(databaseProvider));
    await svc.ensureSchema();
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
    setState(() {
      _pickedPath = f.path;
      _fileName = f.name;
    });
  }

  Future<void> _importToDb() async {
    if (_isImporting) return;
    if (_pickedPath == null) {
      showError(context, 'Primero elegí un archivo.');
      return;
    }
    setState(() => _isImporting = true);
    final svc = ExpensesService(ref.read(databaseProvider));
    try {
      final res = await svc.importFromFile(_pickedPath!, fileName: _fileName);
      showSuccess(context, 'Gastos importados. Insertados: ${res.inserted}, actualizados: ${res.skipped}');
      await _refreshMeta();
    } on FormatException catch (e) {
      showError(context, 'Formato inválido: ${e.message}');
    } catch (e) {
      showError(context, 'Problema en la carga: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
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

  Future<void> _showMonth(DateTime month, String title) async {
    final svc = ExpensesService(ref.read(databaseProvider));
    final rows = await svc.expensesForMonth(month);
    final totals = await svc.totalsForMonth(month);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _ExpensesTableDialog(title: title, rows: rows, totals: totals),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);

    // TODO: reemplazar por tu flag real (por username o provider de auth)
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modificar Gastos'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              tooltip: 'Exportar (CSV)',
              icon: const Icon(Icons.download),
              onPressed: () async {
                try {
                  final db = ref.read(databaseProvider);
                  final path = await exportExpensesCsv(db, month: now);
                  showSuccess(context, 'Exportado a:\n$path');
                } catch (e) {
                  showError(context, 'No se pudo exportar: $e');
                }
              },
            ),
            IconButton(
              tooltip: 'Reset DB (Gastos)',
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Reiniciar tabla de Gastos'),
                    content: const Text('Esto eliminará todos los gastos locales. ¿Continuar?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reiniciar')),
                    ],
                  ),
                ) ?? false;
                if (!ok) return;

                try {
                  final db = ref.read(databaseProvider);
                  await db.execute('DROP TABLE IF EXISTS expenses;');
                  await db.execute('DROP TABLE IF EXISTS expenses_uploads;');
                  // recreate schema + unique index
                  await ExpensesService(db).ensureSchema();
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
                  await _refreshMeta();
                  showSuccess(context, 'Tablas de gastos reiniciadas');
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
                  onPressed: _isImporting ? null : _pickFile,
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
                  onPressed: (_pickedPath != null && !_isImporting) ? _importToDb : null,
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_alt),
                  label: Text(_isImporting ? 'Trabajando...' : 'Importar / Guardar'),
                ),
                if (_fileName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Opacity(opacity: .8, child: Text('Archivo: $_fileName')),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Ver gastos (mes actual / anterior) + Editar
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  onPressed: () => _showMonth(now, 'Gastos (mes actual)'),
                  child: const Text('Ver gastos'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _prevMonthAvailable ? () => _showMonth(prev, 'Gastos (mes anterior)') : null,
                  child: const Text('Ver gastos de mes anterior'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditExpensesScreen()),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar gastos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensesTableDialog extends StatelessWidget {
  final String title;
  final List<ExpenseRow> rows;
  final Map<String, double> totals;
  const _ExpensesTableDialog({
    required this.title,
    required this.rows,
    required this.totals,
  });

  String sectionLabel(String tipo) {
      switch (tipo) {
        case 'factura': return 'Factura A';
        case 'gastos':  return 'Gastos';
        default:        return tipo; // por si aparece algo raro
      }
    }
    
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 820,
        height: 520,
        child: rows.isEmpty
            ? const Center(child: Text('Sin datos para mostrar'))
            : Scrollbar(
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Sección')),
                      DataColumn(label: Text('Categoría')),
                      DataColumn(label: Text('Monto')),
                    ],
                    rows: rows
                        .map(
                          (r) => DataRow(
                            cells: [
                              DataCell(Text(sectionLabel(r.tipo))),
                              DataCell(Text(r.categoria)),
                              // DataCell(Text(r.monto.toStringAsFixed(2))),
                              DataCell(Text(MoneyFmt.format(r.monto))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (totals.isNotEmpty) ...[
                //Text('Factura A: ${totals['factura']?.toStringAsFixed(2) ?? '0.00'}'),
                Text('Factura A: ${MoneyFmt.format(totals['factura'] as num)}'),
                // Text('Gastos:  ${totals['gastos']?.toStringAsFixed(2)  ?? '0.00'}'),
                Text('Gastos:     ${MoneyFmt.format(totals['gastos'] as num)}'),
                /*Text(
                  'TOTAL:   ${totals['total']?.toStringAsFixed(2)   ?? '0.00'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),*/
                Text('TOTAL:     ${MoneyFmt.format(totals['total'] as num)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}
