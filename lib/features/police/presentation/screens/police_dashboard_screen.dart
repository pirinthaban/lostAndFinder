import 'package:flutter/material.dart';

class PoliceDashboardScreen extends StatelessWidget {
  const PoliceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Dashboard')),
      body: const Center(child: Text('Police Verification Dashboard')),
    );
  }
}
