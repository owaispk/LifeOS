import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/quick_actions.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 2. TASKS — Today / Upcoming. Real content arrives in PBI-009.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      title: 'Tasks',
      body: EmptyState(
        emoji: '✅',
        title: 'Nothing on your plate',
        message: 'Add a task and it will show up here for today.',
        actionLabel: '➕ Add task',
        onAction: () => showQuickActionSheet(context, QuickAction.task),
      ),
    );
  }
}
