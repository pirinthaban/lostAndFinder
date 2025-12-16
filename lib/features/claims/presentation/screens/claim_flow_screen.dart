import 'package:flutter/material.dart';

class ClaimFlowScreen extends StatelessWidget {
  final String itemId;
  const ClaimFlowScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Item')),
      body: Center(child: Text('Claim Flow for: $itemId')),
    );
  }
}
