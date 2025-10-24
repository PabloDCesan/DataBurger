import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../../core/tile_theme.dart'; // <-- necesario para TileStyle
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <- para Consumer*
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'dart:convert'; //para LineSplitter por si hay CSV
import 'package:path/path.dart' as p;
import '../../core/db_provider.dart'; // <- para ref.read(databaseProvider)
import '../../core/xls_converter.dart';
import '../sales/sales_service.dart';
import '../../widgets/app_alerts.dart';

class DashboardScreen extends StatelessWidget {
  final String username;
  const DashboardScreen({super.key, required this.username});

  bool get _isAdmin => username.toLowerCase() == 'admin';

  void _logout(BuildContext context) {
    // opcional: confirmar
    // Navigator.of(context).pushAndRemoveUntil(...) limpia historial
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title: const Text('DataBurger – Panel principal'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 900;

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Greeting(username: username),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: isNarrow ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isNarrow ? 1.05 : 1.7,
                    children: [
                      _TileButton(
                        icon: Icons.upload_file,
                        label: 'Modificar Ventas',
                        subtitle: '.xlsx / .csv',
                        onTap: () => _openStub(context, const _ModifySalesScreen()),
                      ),
                      _TileButton(
                        icon: Icons.inventory_2_outlined,
                        label: 'Modificar Stock',
                        subtitle: '.xlsx / .csv',
                        onTap: () => _openStub(context, const _ModifyStockScreen()),
                      ),
                      _TileButton(
                        icon: Icons.receipt_long_outlined,
                        label: 'Configurar Gastos',
                        subtitle: '.xlsx / .csv',
                        onTap: () => _openStub(context, const _ConfigExpensesScreen()),
                      ),
                      _TileButton(
                        icon: Icons.warehouse_outlined,
                        label: 'Ver Stock Actual',
                        subtitle: 'Búsqueda y ajustes',
                        onTap: () => _openStub(context, const _StockScreen()),
                      ),
                      _TileButton(
                        icon: Icons.show_chart,
                        label: 'Ver Ganancias',
                        subtitle: 'Mes en curso',
                        onTap: () => _openStub(context, const _ProfitsScreen()),
                      ),
                      if (_isAdmin)
                        _TileButton(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Usuarios',
                          subtitle: 'Crear / Modificar',
                          onTap: () => _openStub(context, const _UsersScreen()),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openStub(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _Greeting extends StatelessWidget {
  final String username;
  const _Greeting({required this.username});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nice =
        '${username.isNotEmpty ? username[0].toUpperCase() : ''}${username.length > 1 ? username.substring(1) : ''}';
    return Text(
      'Hola, $nice 👋',
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _TileButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  const _TileButton({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  State<_TileButton> createState() => _TileButtonState();
}

class _TileButtonState extends State<_TileButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tile = Theme.of(context).extension<TileStyle>()!;
    final elev = _pressed
        ? tile.pressElevation
        : (_hover ? tile.hoverElevation : tile.elevation);

    // Color por estado (con fallback al base)
    final bgColor = _pressed
        ? (tile.bgPress ?? tile.bg)
        : (_hover ? (tile.bgHover ?? tile.bg) : tile.bg);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() { _hover = false; _pressed = false; }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _pressed ? -1.0 : (_hover ? -0.5 : 0.0)),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(tile.radius),
            border: (tile.borderWidth > 0 && tile.borderColor != null)
                ? Border.all(color: tile.borderColor!, width: tile.borderWidth)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:0.38),
                blurRadius: elev,
                spreadRadius: 0.5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 44, color: tile.fg),
              const SizedBox(height: 12),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tile.fg,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 6),
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tile.fg),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModifySalesScreen extends ConsumerStatefulWidget {
  const _ModifySalesScreen();

  @override
  ConsumerState<_ModifySalesScreen> createState() => _ModifySalesScreenState();
}

class _ModifySalesScreenState extends ConsumerState<_ModifySalesScreen> {
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
    _pickedPath = f.path;
    _fileName   = f.name;
    if (mounted) setState(() {});
  }

  Future<void> _importToDb() async {
    if (_pickedPath == null) {
      showError(context, 'Primero elegí un archivo.');
      return;
    }
    final svc = SalesService(ref.read(databaseProvider));
    try {
      final res = await svc.importSalesFromFile(_pickedPath!, fileName: _fileName);
      // Mensaje claro de resultado
      final msg =
          'Carga realizada.\n'
          'Días nuevos: ${res.insertedDays}, ignorados: ${res.skippedDays}\n'
          'Ingreso Real: ${res.ingresoRealTotal.toStringAsFixed(2)} / '
          'Total: ${res.ingresoTotalTotal.toStringAsFixed(2)} / '
          'Retiros: ${res.retiroAppsTotal.toStringAsFixed(2)}';
      showSuccess(context, msg);

      await _refreshMeta();

      // opcional: limpiar selección
      // setState(() { _pickedPath = null; _fileName = null; });

    } on FormatException catch (e) {
      showError(context, 'Encabezados inválidos: ${e.message}');
    } catch (e) {
      showError(context, 'Problema en la carga: $e');
    }
  }

  String _formatLastUpload(DateTime? dt) {
    if (dt == null) return '—';
    const meses = [
      '', 'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'
    ];
    final dd = dt.day.toString().padLeft(2,'0');
    final mes = meses[dt.month];
    final hh = dt.hour.toString().padLeft(2,'0');
    final mm = dt.minute.toString().padLeft(2,'0');
    return '$dd de $mes a las $hh:$mm';
  }

  Future<void> _showCurrentMonth() async {
    final svc = SalesService(ref.read(databaseProvider));
    final rows = await svc.summaryForMonth(DateTime.now());
    _showTableDialog('Estado actual (mes en curso)', rows);
  }

  Future<void> _showPrevMonth() async {
    final svc = SalesService(ref.read(databaseProvider));
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    final rows = await svc.summaryForMonth(prev);
    _showTableDialog('Estado mes anterior', rows);
  }

  void _showTableDialog(String title, List<Map<String, Object?>> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 850,              // ⬅️ más ancho
          height: 520,             // ⬅️ más alto
          child: rows.isEmpty
              ? const Center(child: Text('Sin datos para mostrar'))
              : Scrollbar(
                  child: SingleChildScrollView(        // ⬅️ scroll vertical
                    child: Center(      // ⬅️ scroll horizontal
                      //scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Día')),
                          DataColumn(label: Text('Ingreso Real')),
                          DataColumn(label: Text('Ingreso Total')),
                          DataColumn(label: Text('Retiros Apps')),
                          DataColumn(label: Text('PedidosYa')),
                          DataColumn(label: Text('Rappi')),
                        ],
                        rows: rows.map((r) => DataRow(cells: [
                          DataCell(Text('${r['day']}')),
                          DataCell(Text('${r['ingreso_real']}')),
                          DataCell(Text('${r['ingreso_total']}')),
                          DataCell(Text('${r['retiro_apps']}')),
                          DataCell(Text('${r['count_pedidosya']}')),
                          DataCell(Text('${r['count_rappi']}')),
                        ])).toList(),
                      ),
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showTotalsDialog(String title, Map<String, Object?> totals) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 900,
          height: 220,
          child: (totals.isEmpty || totals.values.every((v) => v == null))
              ? const Center(child: Text('Sin datos para mostrar'))
              : Center(
                  //scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Primer carga')),  // min(day)
                      DataColumn(label: Text('Última carga')),  // max(day)
                      DataColumn(label: Text('Ingreso Real')),
                      DataColumn(label: Text('Ingreso Total')),
                      DataColumn(label: Text('Retiros Apps')),
                      DataColumn(label: Text('PedidosYa')),
                      DataColumn(label: Text('Rappi')),
                    ],
                    rows: [
                      DataRow(cells: [
                        DataCell(Text('${totals['first_day'] ?? '—'}')),
                        DataCell(Text('${totals['last_day'] ?? '—'}')),
                        DataCell(Text('${totals['ingreso_real'] ?? 0}')),
                        DataCell(Text('${totals['ingreso_total'] ?? 0}')),
                        DataCell(Text('${totals['retiro_apps'] ?? 0}')),
                        DataCell(Text('${totals['count_pedidosya'] ?? 0}')),
                        DataCell(Text('${totals['count_rappi'] ?? 0}')),
                      ]),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Modificar Ventas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Elegir archivo (.xlsx / .xls / .csv)'),
              ),
              const SizedBox(width: 16),
              Text('Última actualización: ${_formatLastUpload(_lastUpload)}'),
              //const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
         //   ],
        //  ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              
              // Botón Importar (sin preview)
              FilledButton.icon(
                onPressed: _pickedPath != null ? _importToDb : null,
                icon: const Icon(Icons.save_alt),
                label: const Text('Importar / Guardar'),
              ),
              // En lugar de: if (_fileName != null) ...[ ... ],
              // armamos un widget auxiliar y lo agregamos como un solo child:
              // Texto con el nombre del archivo (opcional)
              (_fileName != null)
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Opacity(
                        opacity: .8,
                        child: Text('Archivo seleccionado: $_fileName'),
                      ),
                    )
                  : const SizedBox.shrink(),
                 ],
              ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ver estado del presente mes, sumado en una linea
              FilledButton(
                onPressed: _showCurrentMonthTotals,
                child: const Text('Ver estado actual'),
              ),
              const SizedBox(width: 8),
              
              // Ver estado del presente mes, dia a dia
              FilledButton(
                onPressed: _showCurrentMonthDaily,
                child: const Text('Ver estado actual - Diario'),
              ),
              
                 ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mes anterior (totales)
              FilledButton(
                onPressed: _prevMonthAvailable ? _showPrevMonthTotals : null,
                child: const Text('Ver mes anterior'),
              ),
              const SizedBox(width: 8),
              
              // Mes anterior (diario) - ya lo tenías
              FilledButton(
                onPressed: _prevMonthAvailable ? _showPrevMonthDaily : null,
                child: const Text('Ver mes anterior - Diario'),
              ),
              
                 ],
          ),  
        ],
      ),
    );
  }

  Future<void> _showCurrentMonthDaily() async {
    final svc = SalesService(ref.read(databaseProvider));
    final rows = await svc.summaryForMonth(DateTime.now());
    _showTableDialog('Estado actual (diario)', rows);
  }

  Future<void> _showPrevMonthDaily() async {
    final svc = SalesService(ref.read(databaseProvider));
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    final rows = await svc.summaryForMonth(prev);
    _showTableDialog('Estado mes anterior (diario)', rows);
  }

  Future<void> _showCurrentMonthTotals() async {
    final svc = SalesService(ref.read(databaseProvider));
    final m = await svc.summaryMonthTotals(DateTime.now());
    _showTotalsDialog('Estado actual (totales del mes)', m);
  }

  Future<void> _showPrevMonthTotals() async {
    final svc = SalesService(ref.read(databaseProvider));
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    final m = await svc.summaryMonthTotals(prev);
    _showTotalsDialog('Estado mes anterior (totales)', m);
  }

}
/// ==== Stubs de pantallas (para que compile y puedas navegar) ====



class _ModifyStockScreen extends StatelessWidget {
  const _ModifyStockScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Modificar Stock',
      child: const Text('Acá va el flujo para modificar/importar Stock (.xlsx/.csv).'),
    );
  }
}

class _ConfigExpensesScreen extends StatelessWidget {
  const _ConfigExpensesScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Configurar Gastos',
      child: const Text('Acá va el flujo para configurar/importar Gastos (.xlsx/.csv).'),
    );
  }
}

class _StockScreen extends StatelessWidget {
  const _StockScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Ver Stock Actual',
      child: const Text('Tabla de stock, buscador y ajustes/desperdicio.'),
    );
  }
}

class _ProfitsScreen extends StatelessWidget {
  const _ProfitsScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Ver Ganancias',
      child: const Text('Resumen de ingresos, gastos y ganancia neta.'),
    );
  }
}

class _UsersScreen extends StatelessWidget {
  const _UsersScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Usuarios',
      child: const Text('Crear / resetear contraseñas (solo admin).'),
    );
  }
}

class _StubScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _StubScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: child,
        ),
      ),
    );
  }
}
