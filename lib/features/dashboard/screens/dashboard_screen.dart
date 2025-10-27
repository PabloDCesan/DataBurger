import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/greeting.dart';
import '../widgets/tile_button.dart';
import 'modify_sales_screen.dart';
import 'modify_stock_screen.dart';
import 'config_expenses_screen.dart';
import 'stock_screen.dart';
import 'profit_screen.dart';
import 'users_screen.dart';
import '../../auth/login_screen.dart';
import '../../auth/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  final String username;
  const DashboardScreen({super.key, required this.username});

  bool get _isAdmin => username.toLowerCase() == 'admin';

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  await ref.read(authControllerProvider.notifier).logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DataBurger – Panel principal'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context,ref),),
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
                Greeting(username: username),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: isNarrow ? 2 : 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isNarrow ? 1.05 : 1.7,
                    children: [
                      TileButton(
                        icon: Icons.upload_file,
                        label: 'Modificar Ventas',
                        subtitle: '.xlsx / .csv',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ModifySalesScreen(isAdmin: _isAdmin)),
                        ),
                      ),
                      TileButton(
                        icon: Icons.inventory_2_outlined,
                        label: 'Modificar Stock',
                        subtitle: '.xlsx / .csv',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModifyStockScreen()),
                        ),
                      ),
                      TileButton(
                        icon: Icons.receipt_long_outlined,
                        label: 'Configurar Gastos',
                        subtitle: '.xlsx / .csv',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ConfigExpensesScreen()),
                        ),
                      ),
                      TileButton(
                        icon: Icons.warehouse_outlined,
                        label: 'Ver Stock Actual',
                        subtitle: 'Búsqueda y ajustes',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockScreen()),
                        ),
                      ),
                      TileButton(
                        icon: Icons.show_chart,
                        label: 'Ver Ganancias',
                        subtitle: 'Mes en curso',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfitScreen()),
                        ),
                      ),
                      if (_isAdmin)
                        TileButton(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Usuarios',
                          subtitle: 'Crear / Modificar',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UsersScreen()),
                          ),
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
}
