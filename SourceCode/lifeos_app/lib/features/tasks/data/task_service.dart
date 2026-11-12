import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../domain/task_rules.dart';

/// What [TaskService.complete] did, so it can be undone.
class CompletionResult {
  const CompletionResult(this.taskId, this.nextTaskId);
  final String taskId;

  /// The next occurrence created for a repeating task, if any.
  final String? nextTaskId;
}

/// Task use-cases for PBI-009. All writes go through [Repositories], so
/// every change is versioned and queued for sync.
class TaskService {
  TaskService(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  AppDatabase get _db => _repos.db;

  /// Creates a task. Only [title] is required; an all-day [due] is stored as
  /// local midnight.
  Future<Task> create({
    required String title,
    DateTime? due,
    bool allDay = true,
    int priority = 1,
    String domain = 'mind',
    String? personId,
    String? notes,
    int durationMin = 30,
    RepeatFreq? repeat,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(title, 'title', 'empty');
    final dueAt = due == null ? null : (allDay ? startOfDay(due) : due);
    final rule = repeat == null
        ? null
        : RepeatRule.from(repeat, dueAt ?? startOfDay(_now()));
    return _db.transaction(() async {
      final task = await _repos.tasks.insert(
        TasksCompanion.insert(
          title: trimmed,
          notes: Value(notes),
          dueAt: Value(dueAt?.millisecondsSinceEpoch),
          allDay: Value(allDay),
          priority: Value(priority),
          domain: Value(domain),
          personId: Value(personId),
          durationMin: Value(durationMin),
          repeatRule: Value(rule?.format()),
        ),
      );
      // A task with a due *time* gets a default reminder then (PBI-012).
      if (dueAt != null && !allDay) {
        await _repos.taskReminders.insert(
          TaskRemindersCompanion.insert(
            taskId: task.id,
            fireAt: dueAt.millisecondsSinceEpoch,
          ),
        );
      }
      return task;
    });
  }

  /// Moves a task's due date/time. Its reminders move by the same amount,
  /// so "1 hour before" stays one hour before (PBI-012).
  Future<Task> reschedule(String id, DateTime? due, {bool? allDay}) {
    return _db.transaction(() async {
      final task = await _require(id);
      final newAllDay = allDay ?? task.allDay;
      final newDue = due == null ? null : (newAllDay ? startOfDay(due) : due);
      final updated = await _repos.tasks.update(
        id,
        TasksCompanion(
          dueAt: Value(newDue?.millisecondsSinceEpoch),
          allDay: Value(newAllDay),
        ),
      );
      final reminders = await _repos.taskReminders.getWhere(
        (r) => r.taskId.equals(id),
      );
      if (newDue == null) {
        for (final r in reminders) {
          await _repos.taskReminders.softDelete(r.id);
        }
      } else if (task.dueAt != null) {
        final delta = newDue.millisecondsSinceEpoch - task.dueAt!;
        for (final r in reminders.where((r) => delta != 0)) {
          await _repos.taskReminders.update(
            r.id,
            TaskRemindersCompanion(
              fireAt: Value(r.fireAt + delta),
              fired: const Value(false),
            ),
          );
        }
      }
      return updated;
    });
  }

  Future<Task> update(String id, TasksCompanion changes) =>
      _repos.tasks.update(id, changes);

  /// Marks a task done. A repeating task gets exactly one next occurrence
  /// (with its subtasks copied, unchecked). Returns what to undo.
  Future<CompletionResult> complete(String id) {
    return _db.transaction(() async {
      final task = await _require(id);
      final now = _now();
      await _repos.tasks.update(
        id,
        TasksCompanion(
          status: const Value('done'),
          completedAt: Value(now.toUtc().millisecondsSinceEpoch),
        ),
      );

      final rule = RepeatRule.parse(task.repeatRule);
      if (rule == null) return CompletionResult(id, null);

      final base = task.dueAt == null ? startOfDay(now) : localDue(task);
      final nextDue = rule.nextOccurrence(base, now);
      final next = await _repos.tasks.insert(
        TasksCompanion.insert(
          title: task.title,
          notes: Value(task.notes),
          dueAt: Value(nextDue.millisecondsSinceEpoch),
          allDay: Value(task.allDay),
          priority: Value(task.priority),
          domain: Value(task.domain),
          personId: Value(task.personId),
          durationMin: Value(task.durationMin),
          repeatRule: Value(task.repeatRule),
          atcRuleId: Value(task.atcRuleId),
          sourceDocumentId: Value(task.sourceDocumentId),
        ),
      );
      // Reminders keep their offset from the due time (PBI-012).
      if (task.dueAt != null) {
        final reminders = await _repos.taskReminders.getWhere(
          (r) => r.taskId.equals(id),
        );
        for (final r in reminders) {
          final offset = task.dueAt! - r.fireAt;
          await _repos.taskReminders.insert(
            TaskRemindersCompanion.insert(
              taskId: next.id,
              fireAt: nextDue.millisecondsSinceEpoch - offset,
            ),
          );
        }
      }
      for (final s in await subtasksOf(id)) {
        await _repos.subtasks.insert(
          SubtasksCompanion.insert(
            taskId: next.id,
            title: s.title,
            sortOrder: Value(s.sortOrder),
          ),
        );
      }
      return CompletionResult(id, next.id);
    });
  }

  /// Reverses [complete]: reopens the task, removes the next occurrence.
  Future<void> undoComplete(CompletionResult result) {
    return _db.transaction(() async {
      await _repos.tasks.update(
        result.taskId,
        const TasksCompanion(status: Value('open'), completedAt: Value(null)),
      );
      final nextId = result.nextTaskId;
      if (nextId != null) {
        for (final s in await subtasksOf(nextId)) {
          await _repos.subtasks.softDelete(s.id);
        }
        for (final r in await _repos.taskReminders.getWhere(
          (r) => r.taskId.equals(nextId),
        )) {
          await _repos.taskReminders.softDelete(r.id);
        }
        await _repos.tasks.softDelete(nextId);
      }
    });
  }

  /// Reopens a done task at any time (PBI-038 F-01, F-06), without the
  /// [CompletionResult] that [undoComplete] needs. For a repeating task the
  /// occurrence its completion created is removed again while it is still
  /// open: the newest open copy (same title and repeat rule, created after
  /// this task) due exactly when [complete] scheduled the next one.
  Future<void> reopen(String id) {
    return _db.transaction(() async {
      final task = await _require(id);
      if (task.status != 'done') return;
      String? nextId;
      final rule = RepeatRule.parse(task.repeatRule);
      if (rule != null && task.completedAt != null) {
        final doneAt = DateTime.fromMillisecondsSinceEpoch(task.completedAt!);
        final base = task.dueAt == null ? startOfDay(doneAt) : localDue(task);
        final nextDue = rule.nextOccurrence(base, doneAt);
        final copies = (await _repos.tasks.getWhere(
          (t) =>
              t.status.equals('open') &
              t.title.equals(task.title) &
              t.repeatRule.equals(task.repeatRule!) &
              t.dueAt.equals(nextDue.millisecondsSinceEpoch) &
              t.id.isBiggerThanValue(task.id), // UUIDv7 = age
        )).toList()..sort((a, b) => b.id.compareTo(a.id));
        nextId = copies.firstOrNull?.id;
      }
      await undoComplete(CompletionResult(id, nextId));
    });
  }

  /// Done tasks, most recently completed first (PBI-038 F-01).
  Stream<List<Task>> watchCompleted() => _repos.tasks.watchAll().map(
    (all) =>
        all.where((t) => t.status == 'done' && t.completedAt != null).toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!)),
  );

  /// Moves a task to [to]; snoozed tasks become timed.
  Future<Task> snooze(String id, DateTime to) =>
      reschedule(id, to, allDay: false);

  /// "Skip this cycle" for ATC tasks.
  Future<Task> skip(String id) =>
      _repos.tasks.update(id, const TasksCompanion(status: Value('skipped')));

  Future<void> delete(String id) {
    return _db.transaction(() async {
      for (final s in await subtasksOf(id)) {
        await _repos.subtasks.softDelete(s.id);
      }
      await _repos.tasks.softDelete(id);
    });
  }

  /// "Mute this rule": pauses the ATC rule behind a task.
  Future<void> muteRule(String atcRuleId) => _repos.atcRules.update(
    atcRuleId,
    const AtcRulesCompanion(status: Value('paused')),
  );

  // ── Subtasks ────────────────────────────────────────────────────────────

  Future<List<Subtask>> subtasksOf(String taskId) async {
    final list = await _repos.subtasks.getWhere((s) => s.taskId.equals(taskId));
    return list..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Stream<List<Subtask>> watchSubtasks(String taskId) => _repos.subtasks
      .watchWhere((s) => s.taskId.equals(taskId))
      .map((l) => l..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  Future<Subtask> addSubtask(String taskId, String title) async {
    final existing = await subtasksOf(taskId);
    return _repos.subtasks.insert(
      SubtasksCompanion.insert(
        taskId: taskId,
        title: title.trim(),
        sortOrder: Value(existing.length),
      ),
    );
  }

  Future<Subtask> toggleSubtask(Subtask s) =>
      _repos.subtasks.update(s.id, SubtasksCompanion(done: Value(!s.done)));

  Future<void> deleteSubtask(String id) => _repos.subtasks.softDelete(id);

  Future<Task> _require(String id) async {
    final task = await _repos.tasks.getById(id);
    if (task == null) throw StateError('Task $id not found');
    return task;
  }
}
