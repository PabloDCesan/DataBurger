import 'package:flutter/material.dart';

class StubScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const StubScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
    );
  }
}
