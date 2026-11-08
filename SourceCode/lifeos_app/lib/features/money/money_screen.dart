import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/quick_actions.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 4. MONEY — month overview and forecast. Real content in PBI-018/019.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      title: 'Money',
      body: EmptyState(
        emoji: '💰',
        title: 'No expenses yet',
        message: 'Paid bills and quick expenses will add up here.',
        actionLabel: '💸 Add expense',
        onAction: () => showQuickActionSheet(context, QuickAction.expense),
      ),
    );
  }
}
