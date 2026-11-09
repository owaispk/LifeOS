import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/task_rules.dart';
import '../../reminders/domain/reminder_planner.dart';
import '../../reminders/reminder_providers.dart';
import '../tasks_providers.dart';
import 'task_actions.dart';
import 'task_tile.dart';

/// 2.3 Task Detail (UI flow §2.3).
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskByIdProvider(taskId));
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.tkTask)),
      body: task.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            EmptyState(emoji: '⚠️', title: l.tkCantOpen, message: ''),
        data: (t) => t == null
            ? EmptyState(
                emoji: '🗑️',
                title: l.tkGoneTitle,
                message: l.tkGoneBody,
              )
            : _TaskDetailBody(key: ValueKey(t.id), task: t),
      ),
    );
  }
}

class _TaskDetailBody extends ConsumerStatefulWidget {
  const _TaskDetailBody({super.key, required this.task});
  final Task task;

  @override
  ConsumerState<_TaskDetailBody> createState() => _TaskDetailBodyState();
}

class _TaskDetailBodyState extends ConsumerState<_TaskDetailBody> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _notes = TextEditingController(text: widget.task.notes ?? '');
  final _newSubtask = TextEditingController();

  Task get task => widget.task;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _newSubtask.dispose();
    super.dispose();
  }

  Future<void> _update(TasksCompanion changes) =>
      ref.read(taskServiceProvider).update(task.id, changes);

  void _saveTitle() {
    final text = _title.text.trim();
    if (text.isEmpty) {
      _title.text = task.title; // a task always has a title
    } else if (text != task.title) {
      _update(TasksCompanion(title: Value(text)));
    }
  }

  void _saveNotes() {
    final text = _notes.text.trim();
    if (text != (task.notes ?? '')) {
      _update(TasksCompanion(notes: Value(text.isEmpty ? null : text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final now = ref.watch(nowProvider)();
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final subtasks = ref.watch(subtasksProvider(task.id)).value ?? const [];
    final rule = RepeatRule.parse(task.repeatRule);
    final due = task.dueAt == null ? null : localDue(task);

    return ListView(
      padding: EdgeInsets.all(Tokens.spaceM),
      children: [
        TextField(
          key: const ValueKey('detail-title'),
          controller: _title,
          style: theme.textTheme.headlineSmall,
          decoration: const InputDecoration(border: InputBorder.none),
          maxLines: null,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveTitle(),
          onTapOutside: (_) {
            _saveTitle();
            FocusScope.of(context).unfocus();
          },
        ),
        if (task.atcRuleId != null || task.sourceDocumentId != null)
          _SourceLine(task: task),
        const Divider(),

        // Due date + time.
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l.tkDue),
          subtitle: Text(
            due == null
                ? l.tkNoDate
                : dueLabel(due, allDay: task.allDay, now: now),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: due ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 5),
            );
            if (picked == null) return;
            final value = task.allDay || due == null
                ? picked
                : DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    due.hour,
                    due.minute,
                  );
            if (!context.mounted) return;
            // Overload Shield (PBI-011) on rescheduling.
            final resolved = await confirmCapacity(
              context,
              ref,
              due: value,
              durationMin: task.durationMin,
              isAtc: task.atcRuleId != null,
              excludeTaskId: task.id,
            );
            final moved = resolved?.due;
            if (moved == null) return;
            await ref.read(taskServiceProvider).reschedule(task.id, moved);
          },
          trailing: due == null
              ? null
              : IconButton(
                  tooltip: l.tkRemoveDueDate,
                  icon: const Icon(Icons.close),
                  onPressed: () => ref
                      .read(taskServiceProvider)
                      .reschedule(task.id, null, allDay: true),
                ),
        ),
        if (due != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l.tkTime),
            subtitle: Text(task.allDay ? l.tkAllDay : formatTime(due)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: task.allDay
                    ? const TimeOfDay(hour: 9, minute: 0)
                    : TimeOfDay.fromDateTime(due),
              );
              if (picked == null) return;
              final at = DateTime(
                due.year,
                due.month,
                due.day,
                picked.hour,
                picked.minute,
              );
              await ref
                  .read(taskServiceProvider)
                  .reschedule(task.id, at, allDay: false);
            },
            trailing: task.allDay
                ? null
                : TextButton(
                    onPressed: () => ref
                        .read(taskServiceProvider)
                        .reschedule(task.id, startOfDay(due), allDay: true),
                    child: Text(l.tkAllDay),
                  ),
          ),
        _RemindersSection(task: task),
        SizedBox(height: Tokens.spaceS),

        _Label(l.tkPriority),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(l.tkLow)),
            ButtonSegment(value: 1, label: Text(l.tkMedium)),
            ButtonSegment(value: 2, label: Text(l.tkHigh)),
          ],
          selected: {task.priority},
          onSelectionChanged: (s) =>
              _update(TasksCompanion(priority: Value(s.first))),
        ),

        _Label(l.tkLifeArea),
        Wrap(
          spacing: Tokens.spaceS,
          children: [
            for (final d in domainOrder)
              ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: domainColor(d),
                  radius: 5,
                ),
                label: Text(domainLabel(d)),
                selected: task.domain == d,
                onSelected: (_) => _update(TasksCompanion(domain: Value(d))),
              ),
          ],
        ),

        if (persons.isNotEmpty) ...[
          _Label(l.tkFor),
          Wrap(
            spacing: Tokens.spaceS,
            children: [
              for (final p in persons)
                ChoiceChip(
                  label: Text([p.avatar ?? '👤', p.name].join(' ')),
                  selected: task.personId == p.id,
                  onSelected: (on) => _update(
                    TasksCompanion(personId: Value(on ? p.id : null)),
                  ),
                ),
            ],
          ),
        ],

        _Label(l.tkRepeat),
        Wrap(
          spacing: Tokens.spaceS,
          children: [
            ChoiceChip(
              label: Text(l.tkNever),
              selected: rule == null,
              onSelected: (_) =>
                  _update(const TasksCompanion(repeatRule: Value(null))),
            ),
            for (final f in RepeatFreq.values)
              ChoiceChip(
                label: Text(RepeatRule(f).describe()),
                selected: rule?.freq == f,
                onSelected: (_) => _update(
                  TasksCompanion(
                    repeatRule: Value(
                      RepeatRule.from(f, due ?? startOfDay(now)).format(),
                    ),
                  ),
                ),
              ),
          ],
        ),

        _Label(l.tkNotes),
        TextField(
          key: const ValueKey('detail-notes'),
          controller: _notes,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: l.tkAddNotes,
            border: OutlineInputBorder(),
          ),
          onTapOutside: (_) {
            _saveNotes();
            FocusScope.of(context).unfocus();
          },
        ),

        _Label(
          l.tkSubtasks(
            '${subtasks.where((s) => s.done).length}',
            '${subtasks.length}',
          ),
        ),
        for (final s in subtasks)
          CheckboxListTile(
            key: ValueKey('subtask-${s.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: s.done,
            title: Text(
              s.title,
              style: s.done
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            onChanged: (_) => ref.read(taskServiceProvider).toggleSubtask(s),
            secondary: IconButton(
              tooltip: l.tkRemoveSubtask,
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(taskServiceProvider).deleteSubtask(s.id),
            ),
          ),
        TextField(
          key: const ValueKey('detail-add-subtask'),
          controller: _newSubtask,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.add),
            hintText: l.tkAddSubtask,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (text) async {
            if (text.trim().isEmpty) return;
            await ref.read(taskServiceProvider).addSubtask(task.id, text);
            _newSubtask.clear();
          },
        ),

        SizedBox(height: Tokens.spaceXl),
        Wrap(
          spacing: Tokens.spaceS,
          runSpacing: Tokens.spaceS,
          children: [
            if (task.atcRuleId != null) ...[
              OutlinedButton.icon(
                key: const ValueKey('detail-skip'),
                icon: const Icon(Icons.skip_next),
                label: Text(l.tkSkipCycle),
                onPressed: () async {
                  await ref.read(taskServiceProvider).skip(task.id);
                  if (context.mounted) context.go('/tasks');
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('detail-mute'),
                icon: const Icon(Icons.notifications_off_outlined),
                label: Text(l.tkMuteRule),
                onPressed: () async {
                  await ref.read(taskServiceProvider).muteRule(task.atcRuleId!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l.tkRulePaused)));
                  }
                },
              ),
            ],
            TextButton.icon(
              key: const ValueKey('detail-delete'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.tkDelete),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l.tkDeleteTitle),
                    content: Text(l.tkDeleteBody(task.title)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(l.cancel),
                      ),
                      FilledButton(
                        key: const ValueKey('confirm-delete'),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(l.tkDelete),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await ref.read(taskServiceProvider).delete(task.id);
                if (context.mounted) context.go('/tasks');
              },
            ),
          ],
        ),
        SizedBox(height: Tokens.listEnd),
      ],
    );
  }
}

/// "⚡ Created from: K-Electric bill" — opens the source document.
class _SourceLine extends ConsumerWidget {
  const _SourceLine({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docId = task.sourceDocumentId;
    final doc = docId == null ? null : ref.watch(documentProvider(docId)).value;
    final rule = task.atcRuleId == null
        ? null
        : ref.watch(atcRuleProvider(task.atcRuleId!)).value;
    final l = context.l10n;
    final text = doc != null
        ? l.tkCreatedFrom(doc.title)
        : rule != null
        ? l.tkCreatedByRule(rule.name)
        : l.tkCreatedAuto;

    return ListTile(
      key: const ValueKey('detail-source'),
      contentPadding: EdgeInsets.zero,
      leading: const Text('⚡', style: TextStyle(fontSize: 22)),
      title: Text(text),
      trailing: doc == null ? null : const Icon(Icons.chevron_right),
      onTap: doc == null ? null : () => _showDocumentSummary(context, doc),
    );
  }
}

/// Stand-in for the Document Viewer until PBI-007.
void _showDocumentSummary(BuildContext context, Document doc) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    builder: (context) => SafeArea(
      child: Padding(
        key: const ValueKey('document-summary'),
        padding: EdgeInsets.all(Tokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: Tokens.spaceS),
            Text(context.l10n.tkDocType(doc.docType)),
            if (doc.issuer != null) Text(context.l10n.tkDocIssuer(doc.issuer!)),
            if (doc.dueDate != null) Text(context.l10n.tkDocDue(doc.dueDate!)),
          ],
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: Tokens.spaceL, bottom: Tokens.spaceS),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Reminders on a task (PBI-012): list, add (preset offsets or custom),
/// remove. All-day tasks use 09:00 on the due day as the base time.
class _RemindersSection extends ConsumerWidget {
  const _RemindersSection({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(nowProvider)();
    final reminders =
        ref.watch(taskRemindersProvider(task.id)).value ??
        const <TaskReminder>[];
    final due = task.dueAt == null ? null : localDue(task);
    final base = due == null
        ? null
        : task.allDay
        ? DateTime(due.year, due.month, due.day, 9)
        : due;

    Future<void> add(DateTime at) async {
      await ref.read(reminderServiceProvider).add(task.id, at);
      // Ask in context, the first time a reminder is set (PBI-012).
      await ref.read(notificationGatewayProvider).requestPermission();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in reminders)
          ListTile(
            key: ValueKey('reminder-${r.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              r.fireAt < now.millisecondsSinceEpoch
                  ? Icons.notifications_none
                  : Icons.notifications_active_outlined,
            ),
            title: Text(
              dueLabel(
                DateTime.fromMillisecondsSinceEpoch(r.fireAt),
                allDay: false,
                now: now,
              ),
            ),
            trailing: IconButton(
              tooltip: l.tkRemoveReminder,
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(reminderServiceProvider).remove(r.id),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<Object>(
            key: const ValueKey('add-reminder'),
            tooltip: l.tkAddReminder,
            onSelected: (choice) async {
              if (choice is ReminderOffset && base != null) {
                await add(applyOffset(base, choice));
              } else {
                final picked = await pickDateTime(
                  context,
                  initial: base ?? now.add(const Duration(hours: 1)),
                );
                if (picked != null) await add(picked);
              }
            },
            itemBuilder: (context) => [
              if (base != null)
                for (final o in ReminderOffset.values)
                  PopupMenuItem(
                    key: ValueKey('reminder-offset-${o.name}'),
                    value: o,
                    child: Text(offsetLabel(o)),
                  ),
              PopupMenuItem(value: 'custom', child: Text(l.tkPickTime)),
            ],
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: Tokens.spaceS),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_alert_outlined),
                  SizedBox(width: Tokens.spaceS),
                  Text(l.tkAddReminder),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
