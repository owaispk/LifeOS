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
    return _repos.tasks.insert(
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
        await _repos.tasks.softDelete(nextId);
      }
    });
  }

  /// Moves a task to [to]; snoozed tasks become timed.
  Future<Task> snooze(String id, DateTime to) => _repos.tasks.update(
    id,
    TasksCompanion(
      dueAt: Value(to.millisecondsSinceEpoch),
      allDay: const Value(false),
    ),
  );

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
