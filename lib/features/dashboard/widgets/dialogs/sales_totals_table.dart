import 'package:flutter/material.dart';

class SalesTotalsTable extends StatelessWidget {
  final String title;
  final Map<String, Object?> totals;
  const SalesTotalsTable({super.key, required this.title, required this.totals});

  @override
  Widget build(BuildContext context) {
    final empty = totals.isEmpty || totals.values.every((v) => v == null);
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 900,
        height: 220,
        child: empty
            ? const Center(child: Text('Sin datos para mostrar'))
            : Center(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Primer carga')),
                    DataColumn(label: Text('Última carga')),
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
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
