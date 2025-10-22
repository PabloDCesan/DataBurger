import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'core/db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb().open(); // abrir DB! 
  runApp(const ProviderScope(child: DataBurgerApp()));
}

class DataBurgerApp extends StatelessWidget {
  const DataBurgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataBurger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LoginScreen(),
    );
  }
}
