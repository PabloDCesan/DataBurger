import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../../core/tile_theme.dart'; // <-- necesario para TileStyle

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
                color: Colors.black.withOpacity(0.38),
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

/// ==== Stubs de pantallas (para que compile y puedas navegar) ====

class _ModifySalesScreen extends StatelessWidget {
  const _ModifySalesScreen();

  @override
  Widget build(BuildContext context) {
    return _StubScaffold(
      title: 'Modificar Ventas',
      child: const Text('Acá va el flujo para modificar/importar Ventas (.xlsx/.csv).'),
    );
  }
}

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
