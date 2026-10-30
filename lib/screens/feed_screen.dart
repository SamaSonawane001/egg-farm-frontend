import 'package:flutter/material.dart';
import 'feed_inventory_screen.dart';

/// Backward-compatible name for the product-wise feed inventory overview.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => const FeedInventoryScreen();
}
