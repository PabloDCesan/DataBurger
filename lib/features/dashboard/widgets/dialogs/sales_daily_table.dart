import 'package:flutter/material.dart';
import '../../../../core/money_format.dart';

class SalesDailyTable extends StatelessWidget {
  final String title;
  final List<Map<String, Object?>> rows;
  const SalesDailyTable({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 900,
        height: 520,
        child: rows.isEmpty
            ? const Center(child: Text('Sin datos para mostrar'))
            : Scrollbar(
                child: SingleChildScrollView(
                  child: Center(
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
                        //DataCell(Text('${r['ingreso_real']}')),
                        DataCell(Text(MoneyFmt.format((r['ingreso_real'] as num?) ?? 0),),),
                        //DataCell(Text('${r['ingreso_total']}')),
                        DataCell(Text(MoneyFmt.format((r['ingreso_total'] as num?) ?? 0),),),
                        //DataCell(Text('${r['retiro_apps']}')),
                        DataCell(Text(MoneyFmt.format((r['retiro_apps'] as num?) ?? 0),),),
                        DataCell(Text('${r['count_pedidosya']}')),
                        DataCell(Text('${r['count_rappi']}')),
                        
                      ])).toList(),
                    ),
                  ),
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
