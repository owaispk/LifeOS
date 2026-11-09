import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import 'empty_state.dart';

/// The four FAB quick actions (UI flow §1.1).
enum QuickAction {
  task('➕', 'PBI-009'),
  scan('📸', 'PBI-003'),
  voice('🎤', 'PBI-010'),
  expense('💸', 'PBI-018');

  const QuickAction(this.emoji, this.pbi);

  final String emoji;

  /// Short button text ("Task"), in the app's language.
  String get label => switch (this) {
    QuickAction.task => l10nNow.tkQaTask,
    QuickAction.scan => l10nNow.tkQaScan,
    QuickAction.voice => l10nNow.tkQaVoice,
    QuickAction.expense => l10nNow.tkQaExpense,
  };

  /// Sheet title ("Add a task"), in the app's language.
  String get title => switch (this) {
    QuickAction.task => l10nNow.tkQaTaskTitle,
    QuickAction.scan => l10nNow.tkQaScanTitle,
    QuickAction.voice => l10nNow.tkQaVoiceTitle,
    QuickAction.expense => l10nNow.tkQaExpenseTitle,
  };

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
        message: context.l10n.tkComingSoon(action.pbi),
      ),
    ),
  );
}
