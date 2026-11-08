import 'package:flutter/material.dart';

import 'empty_state.dart';

/// The four FAB quick actions (UI flow §1.1).
enum QuickAction {
  task('➕', 'Task', 'Add a task', 'PBI-009'),
  scan('📸', 'Scan', 'Scan a document', 'PBI-003'),
  voice('🎤', 'Voice', 'Speak a task', 'PBI-010'),
  expense('💸', 'Expense', 'Log an expense', 'PBI-018');

  const QuickAction(this.emoji, this.label, this.title, this.pbi);

  final String emoji;
  final String label;
  final String title;

  /// The backlog item that will implement this action.
  final String pbi;
}

/// Placeholder sheet for a quick action until its PBI is built.
Future<void> showQuickActionSheet(BuildContext context, QuickAction action) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    builder: (context) => SizedBox(
      height: 320,
      child: EmptyState(
        key: ValueKey('quick-action-sheet-${action.name}'),
        emoji: action.emoji,
        title: action.title,
        message: 'Coming soon (${action.pbi}).',
      ),
    ),
  );
}
