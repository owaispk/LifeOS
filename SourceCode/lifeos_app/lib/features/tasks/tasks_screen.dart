import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import 'domain/overload.dart';
import 'domain/task_rules.dart';
import 'tasks_providers.dart';
import 'ui/new_task_sheet.dart';
import 'ui/overload_dialog.dart';
import 'ui/task_tile.dart';

enum TasksView { today, upcoming, domains }

/// 2. TASKS — Today · Upcoming · Domains (UI flow §2.1).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TasksView _view = TasksView.today;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider);
    final now = ref.watch(nowProvider)();
    final capacity =
        ref.watch(dayCapacityProvider).value ?? defaultDayCapacityMin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.spaceM,
              0,
              Tokens.spaceM,
              Tokens.spaceS,
            ),
            child: SegmentedButton<TasksView>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TasksView.today, label: Text('Today')),
                ButtonSegment(
                  value: TasksView.upcoming,
                  label: Text('Upcoming'),
                ),
                ButtonSegment(value: TasksView.domains, label: Text('Domains')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
          emoji: '⚠️',
          title: "Tasks aren't available",
          message: 'Local data could not be opened on this device.',
        ),
        data: (list) => switch (_view) {
          TasksView.today => _TodayList(sections: todaySections(list, now)),
          TasksView.upcoming => _UpcomingList(
            days: upcomingByDay(list, now),
            now: now,
            heat: loadsFrom(list, now, 7, capacity),
          ),
          TasksView.domains => _DomainList(groups: tasksByDomain(list)),
        },
      ),
    );
  }
}

// ── Today ───────────────────────────────────────────────────────────────────

const _sectionTitles = {
  TodaySection.overdue: 'Overdue',
  TodaySection.timed: 'Timed',
  TodaySection.payments: 'Payments ⚡',
  TodaySection.anytime: 'Anytime',
};

class _TodayList extends StatelessWidget {
  const _TodayList({required this.sections});
  final Map<TodaySection, List<Task>> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return _AddTaskEmptyState(
        emoji: '✅',
        title: 'Nothing on your plate',
        message: "Add a task and it'll show up here for today.",
      );
    }
    return ListView(
      key: const ValueKey('today-list'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final entry in sections.entries) ...[
          _SectionHeader(
            key: ValueKey('section-${entry.key.name}'),
            title: _sectionTitles[entry.key]!,
            count: entry.value.length,
            danger: entry.key == TodaySection.overdue,
          ),
          for (final t in entry.value) TaskTile(task: t),
        ],
      ],
    );
  }
}

// ── Upcoming ────────────────────────────────────────────────────────────────

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({
    required this.days,
    required this.now,
    required this.heat,
  });
  final Map<DateTime, List<Task>> days;
  final DateTime now;

  /// Today … +6 load for the Overload Shield heatmap (PBI-011).
  final List<DayLoad> heat;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return _AddTaskEmptyState(
        emoji: '📅',
        title: 'A clear week ahead',
        message: 'Nothing is due in the next 7 days.',
      );
    }
    return ListView(
      key: const ValueKey('upcoming-list'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        LoadHeatmap(days: heat),
        for (final entry in days.entries) ...[
          _SectionHeader(
            title: relativeDay(entry.key, now) == 'Tomorrow'
                ? 'Tomorrow · ${formatDay(entry.key)}'
                : formatDay(entry.key, now: now),
            count: entry.value.length,
          ),
          for (final t in entry.value) TaskTile(task: t),
        ],
      ],
    );
  }
}

// ── Domains ─────────────────────────────────────────────────────────────────

class _DomainList extends StatelessWidget {
  const _DomainList({required this.groups});
  final Map<String, List<Task>> groups;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _AddTaskEmptyState(
        emoji: '🗂️',
        title: 'No open tasks',
        message: 'Tasks are grouped by life area here.',
      );
    }
    return ListView(
      key: const ValueKey('domain-list'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final entry in groups.entries) ...[
          _SectionHeader(
            title: domainLabel(entry.key),
            count: entry.value.length,
            dotColor: domainColor(entry.key),
          ),
          for (final t in entry.value) TaskTile(task: t, showDomain: false),
        ],
      ],
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.danger = false,
    this.dotColor,
  });

  final String title;
  final int count;
  final bool danger;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.spaceM,
          Tokens.spaceL,
          Tokens.spaceM,
          Tokens.spaceXs,
        ),
        child: Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Tokens.spaceS),
            ],
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: Tokens.spaceS),
            Text(
              '$count',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskEmptyState extends StatelessWidget {
  const _AddTaskEmptyState({
    required this.emoji,
    required this.title,
    required this.message,
  });

  final String emoji;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      emoji: emoji,
      title: title,
      message: message,
      actionLabel: '➕ Add task',
      onAction: () => showNewTaskSheet(context),
    );
  }
}
