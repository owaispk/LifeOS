import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/platform/calendar_source.dart';
import '../calendar/ui/event_tile.dart';
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
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        // The view switch shares the title bar and shrinks to fit any
        // width or language, so there is no extra band (PBI-031).
        title: Row(
          children: [
            // The title gives way first; the switch keeps its full-size
            // (48 dp) tap targets and scrolls sideways only when even it
            // doesn't fit (Urdu at large text).
            Flexible(
              child: Text(
                l.tkTasks,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: Tokens.spaceS),
            Flexible(
              flex: 4,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TasksView>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: TasksView.today,
                        label: Text(l.today),
                      ),
                      ButtonSegment(
                        value: TasksView.upcoming,
                        label: Text(l.tkUpcoming),
                      ),
                      ButtonSegment(
                        value: TasksView.domains,
                        label: Text(l.tkDomains),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          emoji: '⚠️',
          title: l.tkUnavailableTitle,
          message: l.tkUnavailableBody,
        ),
        data: (list) => switch (_view) {
          TasksView.today => _TodayList(
            sections: todaySections(list, now),
            events: ref.watch(todayEventsProvider),
          ),
          TasksView.upcoming => _UpcomingList(
            days: upcomingByDay(list, now),
            events: ref.watch(upcomingEventsProvider),
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

String _sectionTitle(AppLocalizations l, TodaySection s) => switch (s) {
  TodaySection.overdue => l.tkOverdue,
  TodaySection.timed => l.tkTimed,
  TodaySection.payments => l.tkPayments,
  TodaySection.anytime => l.tkAnytime,
};

class _TodayList extends StatelessWidget {
  const _TodayList({required this.sections, this.events = const []});
  final Map<TodaySection, List<Task>> sections;

  /// Today's device-calendar events (PBI-032), shown above the tasks.
  final List<CalEvent> events;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (sections.isEmpty && events.isEmpty) {
      return _AddTaskEmptyState(
        emoji: '✅',
        title: l.tkEmptyTodayTitle,
        message: l.tkEmptyTodayBody,
      );
    }
    return ListView(
      key: const ValueKey('today-list'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        if (events.isNotEmpty) ...[
          _SectionHeader(
            key: const ValueKey('section-events'),
            title: l.calEventsHeader,
            count: events.length,
          ),
          for (final e in events) EventTile(event: e),
        ],
        for (final entry in sections.entries) ...[
          _SectionHeader(
            key: ValueKey('section-${entry.key.name}'),
            title: _sectionTitle(l, entry.key),
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
    this.events = const {},
  });
  final Map<DateTime, List<Task>> days;

  /// Events by day for the same 7-day window (PBI-032 AC2).
  final Map<DateTime, List<CalEvent>> events;
  final DateTime now;

  /// Today … +6 load for the Overload Shield heatmap (PBI-011).
  final List<DayLoad> heat;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Days with tasks, events or both — in date order.
    final allDays = ({...days.keys, ...events.keys}.toList()..sort());
    if (allDays.isEmpty) {
      return _AddTaskEmptyState(
        emoji: '📅',
        title: l.tkEmptyWeekTitle,
        message: l.tkEmptyWeekBody,
      );
    }
    return ListView(
      key: const ValueKey('upcoming-list'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        LoadHeatmap(days: heat),
        for (final day in allDays) ...[
          _SectionHeader(
            title: relativeDay(day, now) == l.tomorrow
                ? l.tkTomorrowOn(formatDay(day))
                : formatDay(day, now: now),
            count: (days[day]?.length ?? 0) + (events[day]?.length ?? 0),
          ),
          // Events first: they are fixed points the tasks fit around.
          for (final e in events[day] ?? const <CalEvent>[])
            EventTile(event: e),
          for (final t in days[day] ?? const <Task>[]) TaskTile(task: t),
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
        title: context.l10n.tkEmptyDomainsTitle,
        message: context.l10n.tkEmptyDomainsBody,
      );
    }
    return ListView(
      key: const ValueKey('domain-list'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        for (final entry in groups.entries) ...[
          _SectionHeader(
            title: domainLabel(entry.key),
            count: entry.value.length,
            dotColor: domainColor(entry.key, Theme.of(context).brightness),
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
        padding: EdgeInsets.fromLTRB(
          Tokens.gutter,
          Tokens.spaceL,
          Tokens.gutter,
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
              SizedBox(width: Tokens.spaceS),
            ],
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: Tokens.spaceS),
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
      actionLabel: context.l10n.tkAddTaskAction,
      onAction: () => showNewTaskSheet(context),
    );
  }
}
