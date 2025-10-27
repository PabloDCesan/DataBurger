import 'package:flutter/material.dart';

class Greeting extends StatelessWidget {
  final String username;
  const Greeting({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nice = username.isEmpty
        ? ''
        : username[0].toUpperCase() + (username.length > 1 ? username.substring(1) : '');
    return Text('Hola, $nice 👋',
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
