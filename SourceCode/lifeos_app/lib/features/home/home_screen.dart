import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/quick_actions.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 1. HOME — dashboard. Real content arrives in PBI-021.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      title: 'Home',
      body: EmptyState(
        emoji: '🏠',
        title: 'Run your whole life from one app',
        message: 'Scan your first document to get started.',
        actionLabel: '📸 Scan a document',
        onAction: () => showQuickActionSheet(context, QuickAction.scan),
      ),
    );
  }
}
