// What to schedule (PBI-012) — pure, no plugins, no Flutter.
import 'dart:convert';

import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../tasks/domain/task_rules.dart';

/// iOS keeps at most 64 pending notifications; stay under it.
const maxScheduled = 60;

/// Snooze length for notification actions (a setting arrives in PBI-023).
const snoozeMinutes = 60;

enum ReminderKind { task, payment, expiry }

/// Action ids shared by the planner, the platform gateway and the handler.
abstract final class ReminderActions {
  static const done = 'done';
  static const paid = 'paid';
  static const snooze = 'snooze';
  static const renew = 'renew';
  static const dismiss = 'dismiss';

  static List<String> forKind(ReminderKind k) => switch (k) {
    ReminderKind.task => const [done, snooze],
    ReminderKind.payment => const [paid, snooze],
    ReminderKind.expiry => const [renew, dismiss],
  };
}

/// Stable, positive 31-bit notification id for a reminder (FNV-1a).
int notificationIdFor(String reminderId) {
  var hash = 0x811c9dc5;
  for (final unit in reminderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.reminderId,
    required this.taskId,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
  });

  final int id;
  final String reminderId;
  final String taskId;
  final ReminderKind kind;
  final DateTime fireAt;
  final String title;
  final String body;

  List<String> get actions => ReminderActions.forKind(kind);

  String get payload => jsonEncode({'r': reminderId, 't': taskId});

  static ({String reminderId, String taskId})? parsePayload(String? payload) {
    if (payload == null) return null;
    try {
      final m = jsonDecode(payload) as Map<String, dynamic>;
      return (reminderId: m['r'] as String, taskId: m['t'] as String);
    } on Object {
      return null;
    }
  }
}

ReminderKind kindFor(Task task, Payment? payment) {
  if (payment != null && payment.status != 'paid') return ReminderKind.payment;
  if (task.domain == 'vault' && task.sourceDocumentId != null) {
    return ReminderKind.expiry;
  }
  return ReminderKind.task;
}

/// The next [limit] notifications to schedule: live, unfired reminders in
/// the future, on open tasks, soonest first. Completed, skipped or deleted
/// tasks drop out — that is how completing/deleting cancels (AC5).
///
/// Privacy: with [appLock] on, titles are generic and bodies carry no
/// amounts or names (AC6). Expiry notifications are always generic
/// (features spec §1.6 "decoy safety").
List<PlannedNotification> planNotifications({
  required List<TaskReminder> reminders,
  required List<Task> tasks,
  required List<Payment> payments,
  required DateTime now,
  required bool appLock,
  int limit = maxScheduled,
}) {
  final taskById = {for (final t in tasks) t.id: t};
  final paymentByTask = {
    for (final p in payments)
      if (p.taskId != null && p.deletedAt == null) p.taskId!: p,
  };
  final nowMs = now.millisecondsSinceEpoch;

  final planned = <PlannedNotification>[];
  for (final r in reminders) {
    if (r.deletedAt != null || r.fired || r.fireAt <= nowMs) continue;
    final task = taskById[r.taskId];
    if (task == null || !isOpen(task)) continue;
    final payment = paymentByTask[task.id];
    final kind = kindFor(task, payment);
    final (title, body) = _text(task, payment, kind, now, appLock);
    planned.add(
      PlannedNotification(
        id: notificationIdFor(r.id),
        reminderId: r.id,
        taskId: task.id,
        kind: kind,
        fireAt: DateTime.fromMillisecondsSinceEpoch(r.fireAt),
        title: title,
        body: body,
      ),
    );
  }
  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return planned.take(limit).toList();
}

(String, String) _text(
  Task task,
  Payment? payment,
  ReminderKind kind,
  DateTime now,
  bool appLock,
) {
  const hidden = 'Open LifeOS to see details';
  final due = task.dueAt == null
      ? null
      : dueLabel(localDue(task), allDay: task.allDay, now: now);
  switch (kind) {
    case ReminderKind.expiry:
      return ('A document expires soon', 'Tap to see which one and renew it');
    case ReminderKind.payment:
      if (appLock) return ('A payment is due', hidden);
      final amount = payment?.amountMinor == null
          ? null
          : Money.format(payment!.amountMinor!, currency: payment.currency);
      return (task.title, [?amount, if (due != null) 'due $due'].join(' · '));
    case ReminderKind.task:
      if (appLock) return ('A task is due', hidden);
      return (task.title, due == null ? 'Reminder' : 'Due $due');
  }
}

// ─────────────────────── Reminder offsets (Task Detail) ────────────────────

enum ReminderOffset { atDue, min10, hour1, day1 }

String offsetLabel(ReminderOffset o) => switch (o) {
  ReminderOffset.atDue => 'At due time',
  ReminderOffset.min10 => '10 minutes before',
  ReminderOffset.hour1 => '1 hour before',
  ReminderOffset.day1 => '1 day before',
};

DateTime applyOffset(DateTime due, ReminderOffset o) => switch (o) {
  ReminderOffset.atDue => due,
  ReminderOffset.min10 => due.subtract(const Duration(minutes: 10)),
  ReminderOffset.hour1 => due.subtract(const Duration(hours: 1)),
  ReminderOffset.day1 => DateTime(
    due.year,
    due.month,
    due.day - 1,
    due.hour,
    due.minute,
  ),
};
