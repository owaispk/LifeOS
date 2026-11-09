import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
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

/// A life area's name, in the app's language.
String domainLabel(String domain) => switch (domain) {
  'mind' => l10nNow.tkDomainMind,
  'money' => l10nNow.domainMoney,
  'health' => l10nNow.domainHealth,
  'people' => l10nNow.domainPeople,
  'work' => l10nNow.domainWork,
  'soul' => l10nNow.domainSoul,
  'vault' => l10nNow.tkDomainVault,
  '' => domain,
  _ => domain[0].toUpperCase() + domain.substring(1),
};

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
    // A second line only when it says something (PBI-031): ⚡, ‼ or a
    // person. Classic keeps the full chip line with the area.
    final compact = AppSpacing.current.isCompact;
    final meta =
        isAtc(task) ||
        task.priority == 2 ||
        person != null ||
        (!compact && widget.showDomain);
    final l = context.l10n;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      background: _SwipeBackground(
        color: Tokens.scoreHigh,
        icon: Icons.check,
        label: l.tkDone,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: theme.colorScheme.tertiary,
        icon: Icons.snooze,
        label: l.tkSnooze,
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
        minTileHeight: meta ? Tokens.rowTwoLine : Tokens.rowOneLine,
        // The 28 dp circle's left edge lands on the gutter.
        contentPadding: EdgeInsetsDirectional.only(
          start: Tokens.gutter - 6,
          end: Tokens.gutter,
        ),
        onTap: () => context.go('/tasks/task/${task.id}'),
        leading: IconButton(
          key: ValueKey('complete-${task.id}'),
          tooltip: l.tkMarkDone(task.title),
          iconSize: 28,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
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
        title: Row(
          children: [
            // Compact looks: the area is a coloured dot before the title,
            // so most rows stay one line (PBI-031).
            if (compact && widget.showDomain) ...[
              Semantics(
                label: domainLabel(task.domain),
                child: Container(
                  key: const ValueKey('domain-dot'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: domainColor(task.domain),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: Tokens.spaceS),
            ],
            Expanded(
              child: Text(
                task.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: _checked
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
          ],
        ),
        subtitle: meta
            ? _Chips(
                atc: isAtc(task),
                domain: !compact && widget.showDomain ? task.domain : null,
                person: person,
                priority: task.priority,
              )
            : null,
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
          label: context.l10n.tkAutoCreated,
          child: const Text('⚡', key: ValueKey('atc-chip')),
        ),
      if (priority == 2) Text(context.l10n.tkHighChip, style: style),
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
            SizedBox(width: Tokens.spaceXs),
            Text(domainLabel(domain!), style: style),
          ],
        ),
      if (person != null)
        Text([person!.avatar ?? '👤', person!.name].join(' '), style: style),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: Tokens.spaceXs),
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
      padding: EdgeInsets.symmetric(horizontal: Tokens.spaceL),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: Tokens.spaceS),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
