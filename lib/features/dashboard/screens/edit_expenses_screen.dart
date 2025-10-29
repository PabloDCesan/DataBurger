import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db_provider.dart';
import '../../expenses/expenses_service.dart';
import '../../../core/money_format.dart';

class EditExpensesScreen extends ConsumerStatefulWidget {
  const EditExpensesScreen({super.key});
  @override
  ConsumerState<EditExpensesScreen> createState() => _EditExpensesScreenState();
}

class _EditExpensesScreenState extends ConsumerState<EditExpensesScreen> {
  List<ExpenseRow> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }
  
  String sectionLabel(String tipo) {
    switch (tipo) {
      case 'factura': return 'Factura A';
      case 'gastos':  return 'Gastos';
      default:        return tipo; // por si aparece algo raro
    }
  }
  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = ExpensesService(ref.read(databaseProvider));
    await svc.ensureSchema();
    _rows = await svc.expensesForMonth(DateTime.now());
    setState(() => _loading = false);
  }

  Future<void> _addOrEdit({ExpenseRow? base}) async {
    final result = await showDialog<ExpenseRow>(
      context: context,
      builder: (_) => _ExpenseFormDialog(base: base),
    );
    if (result == null) return;

    final svc = ExpensesService(ref.read(databaseProvider));
    if (base == null) {
      final id = await svc.addExpense(result);
      _rows.add(ExpenseRow(
        id: id,
        fecha: result.fecha,
        tipo: result.tipo,
        categoria: result.categoria,
        monto: result.monto,
        nota: result.nota,
      ));
    } else {
      await svc.updateExpense(result);
      final idx = _rows.indexWhere((r) => r.id == result.id);
      if (idx >= 0) _rows[idx] = result;
    }
    if (mounted) setState(() {});
  }

  Future<void> _delete(ExpenseRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Eliminar "${r.categoria}" (${sectionLabel(r.tipo)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    ) ?? false;
    if (!ok) return;

    final svc = ExpensesService(ref.read(databaseProvider));
    if (r.id != null) await svc.deleteExpense(r.id!);
    _rows.removeWhere((e) => e.id == r.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar gastos (mes actual)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(child: Text('Sin gastos cargados para este mes'))
              : Scrollbar(
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Sección')),
                        DataColumn(label: Text('Categoría')),
                        DataColumn(label: Text('Monto')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: _rows.map((r) => DataRow(cells: [
                        DataCell(Text(sectionLabel(r.tipo))),
                        DataCell(Text(r.categoria)),  
                        //DataCell(Text(r.monto.toStringAsFixed(2))),
                        DataCell(Text(MoneyFmt.format(r.monto))),
                        DataCell(Row(
                          children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _addOrEdit(base: r)),
                            IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(r)),
                          ],
                        )),
                      ])).toList(),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  final ExpenseRow? base;
  const _ExpenseFormDialog({this.base});
  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _fecha;
  String _tipo = 'factura';
  final _categoriaCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fecha = DateTime(now.year, now.month, 1); // trabajamos por mes (día=1)
    if (widget.base != null) {
      _fecha = widget.base!.fecha;
      _tipo = widget.base!.tipo;
      _categoriaCtrl.text = widget.base!.categoria;
      _montoCtrl.text = widget.base!.monto.toStringAsFixed(2);
      _notaCtrl.text = widget.base!.nota ?? '';
    }
  }

  @override
  void dispose() {
    _categoriaCtrl.dispose();
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.base == null ? 'Agregar gasto' : 'Editar gasto'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sección / Tipo
              DropdownButtonFormField<String>(
                value: _tipo,
                items: const [
                  DropdownMenuItem(value: 'factura', child: Text('Factura A')),
                  DropdownMenuItem(value: 'gastos', child: Text('Gastos')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? 'factura'),
                decoration: const InputDecoration(labelText: 'Sección'),
              ),
              // Categoría
              TextFormField(
                controller: _categoriaCtrl,
                decoration: const InputDecoration(labelText: 'Categoría'),
                validator: (v) => (v==null || v.trim().isEmpty) ? 'Ingrese una categoría' : null,
              ),
              // Monto
              TextFormField(
                controller: _montoCtrl,
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '') == null) ? 'Monto inválido' : null,
              ),
              // Nota (opcional)
              TextFormField(
                controller: _notaCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final monto = double.parse(_montoCtrl.text.replaceAll(',', '.'));
            final r = ExpenseRow(
              id: widget.base?.id,
              fecha: _fecha,
              tipo: _tipo,
              categoria: _categoriaCtrl.text.trim(),
              monto: monto,
              nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
            );
            Navigator.pop(context, r);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
