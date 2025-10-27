import 'package:flutter/material.dart';
import '../widgets/stub_scaffold.dart';

class ModifyStockScreen extends StatelessWidget {
  const ModifyStockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const StubScaffold(
      title: 'Modificar Stock',
      child: Text('Acá va el flujo para modificar/importar Stock (.xlsx/.csv).'),
    );
  }
}
