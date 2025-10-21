import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = ref.read(authControllerProvider.notifier);
    final ok = await auth.signIn(_userCtrl.text.trim(), _passCtrl.text);
    final st = ref.read(authControllerProvider);
    if (ok) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(username: _userCtrl.text.trim()),
          ),
        );
      }
    } else {
      if (mounted && st.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(st.errorMessage!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(authControllerProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 820;

          final logo = Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            color: const Color(0xFF0B101D),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isNarrow ? 260 : 380,
                maxHeight: isNarrow ? 200 : 320,
              ),
              child: Image.asset(
                'assets/images/logo2.png',
                fit: BoxFit.contain,
                
              ),
            ),
          );

          final form = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFF10162A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Iniciar sesión',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingrese el usuario' : null,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingrese la contraseña' : null,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: st.isLoading ? null : _submit,
                            child: st.isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Entrar'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Opacity(
                          opacity: 0.7,
                          child: Text(
                            'Usuarios demo: admin/admin123 · vanesa/vane123',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          if (isNarrow) {
            // En pantallas angostas: logo arriba, formulario abajo
            return Column(
              children: [
                SizedBox(height: 240, child: SizedBox.expand(child: logo)),
                Expanded(child: form),
              ],
            );
          }

          // Desktop ancho: logo a la izquierda, formulario a la derecha
          return Row(
            children: [
              Expanded(flex: 3, child: logo),
              Expanded(flex: 4, child: form),
            ],
          );
        },
      ),
    );
  }
}
