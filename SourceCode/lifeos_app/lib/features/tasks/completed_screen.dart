import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart' show repositoriesProvider;
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../money/ui/paid_sheet.dart' show confirmMarkUnpaid;
import 'domain/task_rules.dart';
import 'tasks_providers.dart';

/// Done tasks, most recently completed first (PBI-038 F-01).
final completedTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskServiceProvider).watchCompleted(),
);

/// The payment a task stands for, when it was paid: reopening that task
/// means reversing the payment too, or Money and Tasks would disagree.
final paidPaymentForTaskProvider = FutureProvider.family<Payment?, String>((
  ref,
  taskId,
) async {
  ref.watch(completedTasksProvider); // re-read when the list changes
  final list = await ref
      .watch(repositoriesProvider)
      .payments
      .getWhere((p) => p.taskId.equals(taskId) & p.status.equals('paid'));
  return list.firstOrNull;
});

/// Tasks → ⋮ → Completed (design decision D5). Grouped by the day each
/// task was ticked off; each row can be marked not done again.
class CompletedTasksScreen extends ConsumerWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(nowProvider)();
    final done = ref.watch(completedTasksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.tkCompletedTitle)),
      body: done.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          emoji: '⚠️',
          title: l.tkUnavailableTitle,
          message: l.tkUnavailableBody,
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyState(
              key: const ValueKey('completed-empty'),
              emoji: '✅',
              title: l.tkCompletedEmptyTitle,
              message: l.tkCompletedEmptyBody,
            );
          }
          final byDay = <DateTime, List<Task>>{};
          for (final t in tasks) {
            byDay.putIfAbsent(startOfDay(_doneAt(t)), () => []).add(t);
          }
          return ListView(
            key: const ValueKey('completed-list'),
            padding: EdgeInsets.only(bottom: Tokens.listEnd),
            children: [
              for (final entry in byDay.entries) ...[
                SectionHeader(relativeDay(entry.key, now)),
                for (final t in entry.value) _CompletedRow(task: t),
              ],
            ],
          );
        },
      ),
    );
  }
}

DateTime _doneAt(Task t) =>
    DateTime.fromMillisecondsSinceEpoch(t.completedAt!).toLocal();

class _CompletedRow extends ConsumerWidget {
  const _CompletedRow({required this.task});
  final Task task;

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final paid = await ref.read(paidPaymentForTaskProvider(task.id).future);
    if (!context.mounted) return;
    if (paid != null) {
      await confirmMarkUnpaid(
        context,
        ref,
        paymentId: paid.id,
        title: paid.title,
      );
      return;
    }
    await ref.read(taskServiceProvider).reopen(task.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('reopened-snackbar'),
          content: Text(l.tkReopened),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return ListTile(
      key: ValueKey('completed-${task.id}'),
      minTileHeight: Tokens.rowTwoLine,
      leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(l.tkDoneAt(formatTime(_doneAt(task)))),
      onTap: () => context.push('/tasks/task/${task.id}'),
      trailing: IconButton(
        key: ValueKey('reopen-${task.id}'),
        tooltip: l.tkMarkNotDone,
        icon: const Icon(Icons.undo),
        onPressed: () => _reopen(context, ref),
      ),
    );
  }
}
