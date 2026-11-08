import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/quick_actions.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 3. VAULT — folders, people, documents. Real content arrives in PBI-005.
class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      title: 'Vault',
      body: EmptyState(
        emoji: '📂',
        title: 'Your documents live here',
        message: 'Bills, IDs, certificates — scan once, find in seconds.',
        actionLabel: '📸 Scan',
        onAction: () => showQuickActionSheet(context, QuickAction.scan),
      ),
    );
  }
}
