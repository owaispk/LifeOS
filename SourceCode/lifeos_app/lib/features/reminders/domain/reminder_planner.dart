// What to schedule (PBI-012) — pure, no plugins, no Flutter.
import 'dart:convert';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../tasks/domain/task_rules.dart';

/// iOS keeps at most 64 pending notifications; stay under it.
const maxScheduled = 60;

/// Snooze length for notification actions (a setting arrives in PBI-023).
const snoozeMinutes = 60;

enum ReminderKind { task, payment, expiry, digest }

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
    ReminderKind.digest => const [],
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

/// Notification diet (PBI-023): quiet hours, digest time and per-domain
/// switches, from `user_settings`.
class NotifyPrefs {
  const NotifyPrefs({
    this.quietStart = const Duration(hours: 22),
    this.quietEnd = const Duration(hours: 7),
    this.digestAt = const Duration(hours: 7, minutes: 30),
    this.domains = const {},
  });

  /// Parses "HH:mm" settings and the `notif_domains` JSON.
  factory NotifyPrefs.fromSettings({
    required String quietStart,
    required String quietEnd,
    required String digestTime,
    required String notifDomains,
  }) {
    Duration hm(String s) {
      final p = s.split(':');
      return Duration(hours: int.parse(p[0]), minutes: int.parse(p[1]));
    }

    Map<String, bool> domains;
    try {
      domains = (jsonDecode(notifDomains) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v == true),
      );
    } on Object {
      domains = const {};
    }
    return NotifyPrefs(
      quietStart: hm(quietStart),
      quietEnd: hm(quietEnd),
      digestAt: hm(digestTime),
      domains: domains,
    );
  }

  final Duration quietStart;
  final Duration quietEnd;
  final Duration digestAt;

  /// Domain → on/off; a missing domain is on.
  final Map<String, bool> domains;

  bool allows(String domain) => domains[domain] ?? true;

  /// Whether [t]'s time of day falls in quiet hours (may cross midnight).
  bool isQuiet(DateTime t) {
    final m = Duration(hours: t.hour, minutes: t.minute);
    if (quietStart == quietEnd) return false;
    return quietStart < quietEnd
        ? m >= quietStart && m < quietEnd
        : m >= quietStart || m < quietEnd;
  }

  /// The end of the quiet window that [t] is in.
  DateTime quietEndAfter(DateTime t) {
    var end = DateTime(t.year, t.month, t.day).add(quietEnd);
    if (!end.isAfter(t)) end = end.add(const Duration(days: 1));
    return end;
  }

  /// The next digest time strictly after [now].
  DateTime nextDigest(DateTime now) {
    var at = DateTime(now.year, now.month, now.day).add(digestAt);
    if (!at.isAfter(now)) {
      at = DateTime(now.year, now.month, now.day + 1).add(digestAt);
    }
    return at;
  }
}

/// The morning digest's words, written by the caller (localised).
class DigestText {
  const DigestText(this.title, this.body);
  final String title;
  final String body;
}

/// Fixed id for the single digest notification.
const digestNotificationId = 1;

/// The domain a reminder belongs to, for the per-domain switches.
String notifyDomainOf(Task task, ReminderKind kind) => switch (kind) {
  ReminderKind.payment => 'money',
  ReminderKind.expiry => 'vault',
  _ => task.domain,
};

/// Moves a reminder out of quiet hours (AC2), unless the user timed the
/// task itself inside them — then it fires as set.
DateTime dietTime(Task task, DateTime fireAt, NotifyPrefs prefs) {
  if (!prefs.isQuiet(fireAt)) return fireAt;
  final due = task.dueAt == null ? null : localDue(task);
  final timedInside = due != null && !task.allDay && prefs.isQuiet(due);
  return timedInside ? fireAt : prefs.quietEndAfter(fireAt);
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
  NotifyPrefs prefs = const NotifyPrefs(),
  DigestText? digest,
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
    // Per-domain switches (AC3): off means no individual reminders.
    if (!prefs.allows(notifyDomainOf(task, kind))) continue;
    final (title, body) = _text(task, payment, kind, now, appLock);
    planned.add(
      PlannedNotification(
        id: notificationIdFor(r.id),
        reminderId: r.id,
        taskId: task.id,
        kind: kind,
        fireAt: dietTime(
          task,
          DateTime.fromMillisecondsSinceEpoch(r.fireAt),
          prefs,
        ),
        title: title,
        body: body,
      ),
    );
  }
  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  final out = planned.take(digest == null ? limit : limit - 1).toList();
  // One morning digest, never switched off by a domain (AC1, AC3).
  if (digest != null) {
    out.add(
      PlannedNotification(
        id: digestNotificationId,
        reminderId: 'digest',
        taskId: '',
        kind: ReminderKind.digest,
        fireAt: prefs.nextDigest(now),
        title: digest.title,
        body: digest.body,
      ),
    );
    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  }
  return out;
}

/// What the digest counts for the day it fires: open tasks due that day
/// and unpaid payments due that day.
({int tasks, int bills}) digestCounts({
  required List<Task> tasks,
  required List<Payment> payments,
  required DateTime day,
}) {
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day + 1);
  final iso =
      '${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}';
  final paymentTasks = {
    for (final p in payments)
      if (p.taskId != null) p.taskId!,
  };
  var t = 0;
  for (final task in tasks) {
    if (!isOpen(task) || task.dueAt == null) continue;
    if (paymentTasks.contains(task.id)) continue; // counted as bills
    final due = localDue(task);
    if (!due.isBefore(start) && due.isBefore(end)) t++;
  }
  final b = payments
      .where(
        (p) =>
            p.deletedAt == null &&
            p.status != 'paid' &&
            p.status != 'skipped' &&
            p.dueDate == iso,
      )
      .length;
  return (tasks: t, bills: b);
}

(String, String) _text(
  Task task,
  Payment? payment,
  ReminderKind kind,
  DateTime now,
  bool appLock,
) {
  final l = l10nNow;
  final hidden = l.tkNotifHidden;
  final due = task.dueAt == null
      ? null
      : dueLabel(localDue(task), allDay: task.allDay, now: now);
  switch (kind) {
    case ReminderKind.expiry:
      return (l.tkNotifExpiryTitle, l.tkNotifExpiryBody);
    case ReminderKind.payment:
      if (appLock) return (l.tkNotifPaymentTitle, hidden);
      final amount = payment?.amountMinor == null
          ? null
          : Money.format(payment!.amountMinor!);
      return (
        task.title,
        [?amount, if (due != null) l.tkNotifDueLower(due)].join(' · '),
      );
    case ReminderKind.digest:
      return ('', '');
    case ReminderKind.task:
      if (appLock) return (l.tkNotifTaskTitle, hidden);
      return (task.title, due == null ? l.tkNotifReminder : l.tkNotifDue(due));
  }
}

// ─────────────────────── Reminder offsets (Task Detail) ────────────────────

enum ReminderOffset { atDue, min10, hour1, day1 }

String offsetLabel(ReminderOffset o) => switch (o) {
  ReminderOffset.atDue => l10nNow.tkOffsetAtDue,
  ReminderOffset.min10 => l10nNow.tkOffset10m,
  ReminderOffset.hour1 => l10nNow.tkOffset1h,
  ReminderOffset.day1 => l10nNow.tkOffset1d,
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
