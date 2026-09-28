// ============================================================
// As Above, So Below. As Within, So Below.
// The Future Dictates the Past and the Past is Always Present.
// ============================================================

import 'package:flutter/material.dart';

import '../widgets/native_resources_grid.dart';

/// In-person, culturally specific Native recovery resources across
/// Minnesota (data: Khunsi Onikan and sibling programs).
class NativeResourcesScreen extends StatelessWidget {
  const NativeResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Native Recovery Resources'),
      ),
      body: const NativeResourcesGrid(),
    );
  }
}
