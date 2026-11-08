import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../domain/task_rules.dart';
import '../tasks_providers.dart';
import 'task_actions.dart';

Color domainColor(String domain) {
  final d = LifeDomain.values.where((e) => e.name == domain).firstOrNull;
  return d == null ? Tokens.domain(LifeDomain.mind) : Tokens.domain(d);
}

String domainLabel(String domain) =>
    domain.isEmpty ? domain : domain[0].toUpperCase() + domain.substring(1);

/// One task row: `○ checkbox · title · chips(⚡/domain/person) · due`.
/// Swipe right completes, swipe left snoozes, tap opens the detail.
class TaskTile extends ConsumerStatefulWidget {
  const TaskTile({super.key, required this.task, this.showDomain = true});

  final Task task;
  final bool showDomain;

  @override
  ConsumerState<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<TaskTile> {
  bool _checked = false;

  Future<void> _complete() async {
    if (_checked) return;
    setState(() => _checked = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await completeWithUndo(context, ref, widget.task);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final person = persons.where((p) => p.id == task.personId).firstOrNull;
    final overdue = isOverdue(task, now);

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      background: _SwipeBackground(
        color: Tokens.scoreHigh,
        icon: Icons.check,
        label: 'Done',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: theme.colorScheme.tertiary,
        icon: Icons.snooze,
        label: 'Snooze',
        alignment: Alignment.centerRight,
      ),
      // Rows leave via the data stream, never by the Dismissible itself.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await completeWithUndo(context, ref, task);
        } else {
          await snoozeTask(context, ref, task);
        }
        return false;
      },
      child: ListTile(
        minTileHeight: 64,
        onTap: () => context.go('/tasks/task/${task.id}'),
        leading: IconButton(
          key: ValueKey('complete-${task.id}'),
          tooltip: 'Mark "${task.title}" done',
          iconSize: 28,
          onPressed: _complete,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _checked
                ? Icon(
                    Icons.check_circle,
                    key: const ValueKey('checked'),
                    color: Tokens.scoreHigh,
                  )
                : Icon(
                    Icons.radio_button_unchecked,
                    key: const ValueKey('unchecked'),
                    color: theme.colorScheme.outline,
                  ),
          ),
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _checked
              ? const TextStyle(decoration: TextDecoration.lineThrough)
              : null,
        ),
        subtitle: _Chips(
          atc: isAtc(task),
          domain: widget.showDomain ? task.domain : null,
          person: person,
          priority: task.priority,
        ),
        trailing: task.dueAt == null
            ? null
            : Text(
                dueLabel(localDue(task), allDay: task.allDay, now: now),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: overdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.atc,
    required this.domain,
    required this.person,
    required this.priority,
  });

  final bool atc;
  final String? domain;
  final Person? person;
  final int priority;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final chips = <Widget>[
      if (atc)
        Semantics(
          label: 'Auto-created',
          child: const Text('⚡', key: ValueKey('atc-chip')),
        ),
      if (priority == 2) Text('‼ High', style: style),
      if (domain != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: domainColor(domain!),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(domainLabel(domain!), style: style),
          ],
        ),
      if (person != null)
        Text('${person!.avatar ?? '👤'} ${person!.name}', style: style),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.spaceXs),
      child: Wrap(spacing: Tokens.spaceS, runSpacing: 2, children: chips),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceL),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: Tokens.spaceS),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
