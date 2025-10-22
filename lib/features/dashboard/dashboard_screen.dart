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
  List<List<dynamic>> _preview = [];
  String? _fileName;
  DateTime? _lastUpload;
  bool _prevMonthAvailable = false;
  List<Map<String, Object?>> _currentMonth = [];
  List<Map<String, Object?>> _prevMonth = [];
  String? _pickedPath;

  Future<void> _refreshMeta() async {
    final svc = SalesService(ref.read(databaseProvider));
    _lastUpload = await svc.lastUploadAt();
    _prevMonthAvailable = await svc.hasPreviousMonthData(DateTime.now());
    setState(() {});
  }

  String _formatLastUpload(DateTime? dt) {
    if (dt == null) return '—';
    // dd de MES a las hh:mm (24h)
    const meses = [
      '', 'enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'
    ];
    final dd = dt.day.toString().padLeft(2,'0');
    final mes = meses[dt.month];
    final hh = dt.hour.toString().padLeft(2,'0');
    final mm = dt.minute.toString().padLeft(2,'0');
    return '$dd de $mes a las $hh:$mm';
  }

  Future<void> _showCurrentMonth() async {
    final svc = SalesService(ref.read(databaseProvider));
    _currentMonth = await svc.summaryForMonth(DateTime.now());
    _showTableDialog('Estado actual (mes en curso)', _currentMonth);
  }

  Future<void> _showPrevMonth() async {
    final svc = SalesService(ref.read(databaseProvider));
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1, 1);
    _prevMonth = await svc.summaryForMonth(prev);
    _showTableDialog('Estado mes anterior', _prevMonth);
  }
  
  // Limpia encabezados (quita comillas, trim)
  String _cleanHeader(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.replaceAll('"', '').replaceAll("'", '');
  }

  // Construcción segura del DataTable a partir de _preview
  Widget buildPreviewTable() {
    if (_preview.isEmpty) return const SizedBox.shrink();

    // 1) La primera fila son los headers
    final rawHeader = _preview.first;
    final headers = rawHeader.map(_cleanHeader).toList();
    final colCount = headers.length;

    // 2) Filas de datos = resto
    final dataRows = _preview.length > 1 ? _preview.sublist(1) : const <List<dynamic>>[];

    // 3) Columnas
    final columns = [
      for (var i = 0; i < colCount; i++)
        DataColumn(label: Text(headers[i].isEmpty ? 'Col ${i + 1}' : headers[i])),
    ];

    // 4) Filas, ajustando largo (pad/trunc)
    final rows = <DataRow>[
      for (final row in dataRows)
        DataRow(
          cells: List.generate(colCount, (i) {
            final val = i < row.length ? row[i] : '';
            return DataCell(Text('${val ?? ''}'));
          }),
        ),
    ];

    return SizedBox(
      height: 360,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }

  void _showTableDialog(String title, List<Map<String, Object?>> rows) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 640, height: 420,
          child: rows.isEmpty
              ? const Center(child: Text('Sin datos para mostrar'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Día')),
                      DataColumn(label: Text('Ingreso Real')),
                      DataColumn(label: Text('Ingreso Total')),
                      DataColumn(label: Text('Retiros Apps')),
                      DataColumn(label: Text('PedidosYa')),
                      DataColumn(label: Text('Rappi')),
                    ],
                    rows: rows.map((r) {
                      return DataRow(cells: [
                        DataCell(Text('${r['day']}')),
                        DataCell(Text('${r['ingreso_real']}')),
                        DataCell(Text('${r['ingreso_total']}')),
                        DataCell(Text('${r['retiro_apps']}')),
                        DataCell(Text('${r['count_pedidosya']}')),
                        DataCell(Text('${r['count_rappi']}')),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  Future<void> _pickAndPreview() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv', 'xls'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    String? path = file.path;
    _pickedPath = file.path; // guarda la ruta original
    _fileName = file.name;

    final ext = (file.extension ?? '').toLowerCase();

    try {
      if (ext == 'xls') {
        // 1) Convertir automáticamente
        final xlsxPath = await convertXlsToXlsxWindows(path!);
        path = xlsxPath;
        _pickedPath = xlsxPath; //actualizar para el import
        //_fileName = '${p.basenameWithoutExtension(_fileName!)}.xlsx (convertido)';
        // cambio hecho por si filename fuese null:
        final base = p.basenameWithoutExtension(_fileName ?? path);
        _fileName = '$base.xlsx (convertido)';
      }

      if (path == null) return;
        // ACA
      if (path.toLowerCase().endsWith('.xlsx')) {if (path.toLowerCase().endsWith('.xlsx')) {
        try {
          // Intento normal con paquete excel
          final bytes = await File(path).readAsBytes();
          final ex = Excel.decodeBytes(bytes);  // si aliaste: xls.Excel.decodeBytes(bytes)
          final sheet = ex.tables.values.first;

          _preview = [];
          for (var r = 0; r < sheet.maxRows && r < 20; r++) {
            final row = sheet.row(r).map((c) => c?.value).toList();
            _preview.add(row);
          }
        } catch (e) {
          // ⛑️ Fallback robusto: convertir a CSV con PowerShell y leer CSV
          final csvPath = await convertXlsxToCsvWindows(path);
          final content = await File(csvPath).readAsString();
          final csv = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);

          _preview = [];
          final max = csv.length < 20 ? csv.length : 20;
          for (var r = 0; r < max; r++) {
            final row = csv[r].map((e) => e?.toString() ?? '').toList();
            _preview.add(row);
          }
        }
      } else if (path.toLowerCase().endsWith('.csv')) {
        final content = await File(path).readAsString();
        final lines = const LineSplitter().convert(content);
        _preview = [];
        for (var i = 0; i < lines.length && i < 20; i++) {
          _preview.add(lines[i].split(',')); // básico; luego metemos paquete csv para comillas/separadores
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato no soportado. Use .xlsx, .csv o .xls (se convierte).')),
        );
        return;
      }

      setState(() {});
    }} catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo procesar el archivo: $e')),
      );
    }
  }

Future<void> _importToDb() async {
  if (_pickedPath == null) { /* ... */ return; }
  final svc = SalesService(ref.read(databaseProvider));
  try {
    final res = await svc.importSalesFromFile(_pickedPath!, fileName: _fileName);

    final msg =
        'Días nuevos: ${res.insertedDays}, ignorados: ${res.skippedDays}\n'
        'Ingreso Real: ${res.ingresoRealTotal.toStringAsFixed(2)}\n'
        'Ingreso Total: ${res.ingresoTotalTotal.toStringAsFixed(2)}\n'
        'Retiros Apps: ${res.retiroAppsTotal.toStringAsFixed(2)}\n'
        'PedidosYa: ${res.countPedidosYaTotal}, Rappi: ${res.countRappiTotal}';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _refreshMeta();
  } on FormatException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Encabezados inválidos: ${e.message}')),);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al importar: $e')),
    );
  }
}

  @override
  void initState() {
    super.initState();
    _refreshMeta();
  }

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Modificar Ventas',
      child: Column(
        mainAxisSize: MainAxisSize.min,
         crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _pickAndPreview,
                icon: const Icon(Icons.folder_open),
                label: const Text('Elegir archivo (.xlsx / .xls / .csv)'),
              ),
              const SizedBox(width: 16),
              Text('Última actualización: ${_formatLastUpload(_lastUpload)}'),
              const Spacer(),
              FilledButton(
                onPressed: _showCurrentMonth,
                child: const Text('Ver estado actual'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _prevMonthAvailable ? _showPrevMonth : null,
                child: const Text('Ver estado de mes anterior'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_fileName != null) Text('Archivo: $_fileName'),
          const SizedBox(height: 12),
          if (_preview.isNotEmpty)
            SizedBox(
              height: 360,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    for (var i = 0; i < (_preview.first.length); i++)
                      DataColumn(label: Text('Col ${i + 1}')),
                  ],
                  rows: [
                    for (var r = 0; r < _preview.length; r++)
                      DataRow(
                        cells: [
                          for (final cell in _preview[r]) DataCell(Text('${cell ?? ''}')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_preview.isNotEmpty)
            FilledButton.icon(
              onPressed: _importToDb,
              icon: const Icon(Icons.save_alt),
              label: const Text('Importar / Guardar'),
            ),
        ],
      ),
    );
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
