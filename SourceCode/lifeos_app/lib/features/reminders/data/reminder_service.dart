import 'package:drift/drift.dart';

import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/data/payment_service.dart';
import '../../tasks/data/task_service.dart';
import '../domain/reminder_planner.dart';

/// Reminder use-cases and notification-action handling (PBI-012).
class ReminderService {
  ReminderService(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  Future<List<TaskReminder>> remindersOf(String taskId) async {
    final list = await _repos.taskReminders.getWhere(
      (r) => r.taskId.equals(taskId),
    );
    return list..sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }

  Stream<List<TaskReminder>> watchReminders(String taskId) => _repos
      .taskReminders
      .watchWhere((r) => r.taskId.equals(taskId))
      .map((l) => l..sort((a, b) => a.fireAt.compareTo(b.fireAt)));

  /// Adds a reminder unless one already exists at that exact time.
  Future<TaskReminder?> add(String taskId, DateTime fireAt) async {
    final ms = fireAt.millisecondsSinceEpoch;
    final existing = await remindersOf(taskId);
    if (existing.any((r) => r.fireAt == ms)) return null;
    return _repos.taskReminders.insert(
      TaskRemindersCompanion.insert(taskId: taskId, fireAt: ms),
    );
  }

  Future<void> remove(String reminderId) =>
      _repos.taskReminders.softDelete(reminderId);

  /// Moves a reminder to now + [snoozeMinutes] and re-arms it.
  Future<TaskReminder> snooze(String reminderId) => _repos.taskReminders.update(
    reminderId,
    TaskRemindersCompanion(
      fireAt: Value(
        _now()
            .add(const Duration(minutes: snoozeMinutes))
            .millisecondsSinceEpoch,
      ),
      fired: const Value(false),
    ),
  );

  Future<void> markFired(String reminderId) => _repos.taskReminders.update(
    reminderId,
    const TaskRemindersCompanion(fired: Value(true)),
  );

  /// Handles a notification action, in the app or in the background
  /// isolate. Returns false when the payload no longer matches live data.
  Future<bool> handleAction(String? actionId, String? payload) async {
    final ref = PlannedNotification.parsePayload(payload);
    if (ref == null) return false;
    final task = await _repos.tasks.getById(ref.taskId);
    final reminder = await _repos.taskReminders.getById(ref.reminderId);
    if (task == null || reminder == null) return false;
    final tasks = TaskService(_repos, now: _now);

    switch (actionId) {
      case ReminderActions.done:
        if (task.status == 'open') await tasks.complete(task.id);
      case ReminderActions.paid:
        // The completion chain (PBI-016), without a receipt: payment paid,
        // expense logged, task done.
        final payments = PaymentService(_repos, now: _now);
        final unpaid = await payments.unpaidForTask(task.id);
        if (unpaid == null) {
          if (task.status == 'open') await tasks.complete(task.id);
        } else {
          try {
            await payments.markPaid(unpaid.id);
          } on MissingAmountException {
            // Unknown amount: can't log an expense from the notification;
            // the task stays open so the app asks for it.
            return false;
          }
        }
      case ReminderActions.snooze:
        await snooze(reminder.id);
      case ReminderActions.renew:
        final doc = task.sourceDocumentId == null
            ? null
            : await _repos.documents.getById(task.sourceDocumentId!);
        final n = _now();
        await tasks.create(
          title: l10nNow.tkRenewTitle(doc?.title ?? l10nNow.tkRenewDocument),
          due: DateTime(n.year, n.month, n.day + 1),
          domain: 'vault',
          priority: 2,
        );
        await markFired(reminder.id);
      case ReminderActions.dismiss:
        await markFired(reminder.id);
      default:
        // A tap on the notification body just opens the app.
        return true;
    }
    return true;
  }
}
