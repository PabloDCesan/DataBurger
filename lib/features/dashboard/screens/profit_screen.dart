import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db_provider.dart';
import '../../../core/money_format.dart';

class ProfitScreen extends ConsumerStatefulWidget {
  const ProfitScreen({super.key});
  @override
  ConsumerState<ProfitScreen> createState() => _ProfitScreenState();
}

class _ProfitScreenState extends ConsumerState<ProfitScreen> {
  bool _loading = true;
  String? _error;

  // datos
  double _ingresoTotal = 0;
  double _retirosApps = 0;
  double _gastosGenerales = 0;
  double _gastosFactura = 0;

  // meses disponibles y seleccionado (formato "YYYY-MM")
  List<String> _months = [];
  String? _selectedYm;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _loadAvailableMonths();
      if (_selectedYm == null && _months.isNotEmpty) {
        // intenta mes actual si está; si no, el primero de la lista (más reciente)
        final now = DateTime.now();
        final currentYm = _ymFromDate(now);
        _selectedYm = _months.contains(currentYm) ? currentYm : _months.first;
      }
      await _loadForMonth(_selectedYm);
    } catch (e) {
      _error = 'No se pudo inicializar: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  String _ymFromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  String _labelFromYm(String ym) {
    final parts = ym.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    const monthNames = [
      '', 'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'
    ];
    return '${monthNames[m]} $y';
  }

  Future<void> _loadAvailableMonths() async {
    final db = ref.read(databaseProvider);
    final rows = await db.rawQuery(
      // Toma meses distintos de ventas (day) y gastos (fecha), los une, ordena desc y limita 6
      'SELECT ym FROM ('
      ' SELECT DISTINCT substr(day,1,7) AS ym FROM daily_sales_summary'
      ' UNION '
      ' SELECT DISTINCT substr(fecha,1,7) AS ym FROM expenses'
      ') AS u '
      'WHERE ym IS NOT NULL '
      'ORDER BY ym DESC '
      'LIMIT 6;'
    );
    _months = rows.map((r) => (r['ym'] as String)).toList();
  }

  Future<void> _loadForMonth(String? ym) async {
    if (ym == null) return;
    setState(() { _loading = true; _error = null; });
    final db = ref.read(databaseProvider);
    try {
      // Ventas
      final sales = await db.rawQuery(
        'SELECT IFNULL(SUM(ingreso_total),0) AS ingreso_total, '
        '       IFNULL(SUM(retiro_apps),0)  AS retiro_apps '
        'FROM daily_sales_summary '
        'WHERE substr(day,1,7)=?',
        [ym],
      );
      if (sales.isNotEmpty) {
        final r = sales.first;
        _ingresoTotal = (r['ingreso_total'] as num).toDouble();
        _retirosApps  = (r['retiro_apps']  as num).toDouble();
      } else {
        _ingresoTotal = 0; _retirosApps = 0;
      }

      // Gastos
      final expenses = await db.rawQuery(
        'SELECT '
        '  IFNULL(SUM(CASE WHEN tipo="gastos"  THEN monto ELSE 0 END),0) AS gastos_generales, '
        '  IFNULL(SUM(CASE WHEN tipo="factura" THEN monto ELSE 0 END),0) AS gastos_factura '
        'FROM expenses '
        'WHERE substr(fecha,1,7)=?',
        [ym],
      );
      if (expenses.isNotEmpty) {
        final r = expenses.first;
        _gastosGenerales = (r['gastos_generales'] as num).toDouble();
        _gastosFactura   = (r['gastos_factura']   as num).toDouble();
      } else {
        _gastosGenerales = 0; _gastosFactura = 0;
      }
    } catch (e) {
      _error = 'No se pudo cargar datos para $ym: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ym = _selectedYm;
    final tituloMes = ym == null ? '' : _labelFromYm(ym);
    final gananciaNeta = _ingresoTotal - _retirosApps - _gastosGenerales - _gastosFactura;
    final margen = _ingresoTotal == 0 ? 0.0 : (gananciaNeta / _ingresoTotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ganancias'),
        actions: [
          if (_months.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedYm,
                  items: _months.map((m) {
                    return DropdownMenuItem<String>(
                      value: m,
                      child: Text(_labelFromYm(m)),
                    );
                  }).toList(),
                  onChanged: (v) async {
                    if (v == null || v == _selectedYm) return;
                    setState(() => _selectedYm = v);
                    await _loadForMonth(v);
                  },
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _init,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : Center(
                  child: Card(
                    elevation: 1,
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (ym != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Estado actual ( $tituloMes )',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          DataTable(
                            columns: const [
                              DataColumn(label: Text('Concepto')),
                              DataColumn(label: Text('Monto')),
                            ],
                            rows: [
                              DataRow(cells: [
                                const DataCell(Text('Ingreso total (a la fecha)')),
                                DataCell(Text(MoneyFmt.format(_ingresoTotal))),
                              ]),
                              DataRow(cells: [
                                const DataCell(Text('Retiros app (a la fecha)')),
                                DataCell(Text(MoneyFmt.format(_retirosApps))),
                              ]),
                              const DataRow(cells: [
                                DataCell(SizedBox(height: 8)), // separador visual
                                DataCell(SizedBox()),
                              ]),
                              DataRow(cells: [
                                const DataCell(Text('Gastos generales')),
                                DataCell(Text(MoneyFmt.format(_gastosGenerales))),
                              ]),
                              DataRow(cells: [
                                const DataCell(Text('Gastos Factura A')),
                                DataCell(Text(MoneyFmt.format(_gastosFactura))),
                              ]),
                              const DataRow(cells: [
                                DataCell(SizedBox(height: 8)),
                                DataCell(SizedBox()),
                              ]),
                              DataRow(cells: [
                                const DataCell(Text('Ganancia Neta (a la fecha)', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(MoneyFmt.format(gananciaNeta), style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]),
                              DataRow(cells: [
                                const DataCell(Text('Margen (%)')),
                                DataCell(Text('${(margen * 100).toStringAsFixed(2)} %')),
                              ]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
