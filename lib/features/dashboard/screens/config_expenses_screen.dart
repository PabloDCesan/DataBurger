import 'package:flutter/material.dart';
import '../widgets/stub_scaffold.dart';

class ConfigExpensesScreen extends StatelessWidget {
  const ConfigExpensesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const StubScaffold(
      title: 'Modificar Stock',
      child: Text('Acá va el flujo para modificar/importar Stock (.xlsx/.csv).'),
    );
  }
}