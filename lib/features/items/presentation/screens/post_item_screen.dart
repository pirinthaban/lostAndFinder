import 'package:flutter/material.dart';

// Placeholder screens
class PostItemScreen extends StatelessWidget {
  final String? itemType;
  const PostItemScreen({super.key, this.itemType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Item')),
      body: Center(child: Text('Post ${itemType ?? 'Item'} Screen')),
    );
  }
}

class PostItemDetailScreen extends StatelessWidget {
  final String itemId;
  const PostItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Item Details')),
      body: Center(child: Text('Item Detail: $itemId')),
    );
  }
}
