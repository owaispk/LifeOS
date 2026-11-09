// Pure task logic for PBI-009 — no database, no Flutter. All "now" values
// are local DateTimes; task timestamps are UTC epoch-ms.
import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime localDue(Task t) => DateTime.fromMillisecondsSinceEpoch(t.dueAt!);

bool isOpen(Task t) => t.status == 'open' && t.deletedAt == null;

bool isAtc(Task t) => t.atcRuleId != null;

/// Overdue: timed and past its time, or all-day and due before today.
bool isOverdue(Task t, DateTime now) {
  if (t.dueAt == null) return false;
  final due = localDue(t);
  return t.allDay ? due.isBefore(startOfDay(now)) : due.isBefore(now);
}

// ───────────────────────────────── Today ───────────────────────────────────

enum TodaySection { overdue, timed, payments, anytime }

/// Today view (features spec §3.1): Overdue → Timed (chronological) →
/// Payments ⚡ (by due date) → Anytime (by priority). Only open tasks that
/// are undated, due today, or overdue are included. Empty sections are
/// omitted.
Map<TodaySection, List<Task>> todaySections(List<Task> tasks, DateTime now) {
  final tomorrow = startOfDay(now).add(const Duration(days: 1));
  final buckets = {for (final s in TodaySection.values) s: <Task>[]};

  for (final t in tasks.where(isOpen)) {
    if (t.dueAt != null && !localDue(t).isBefore(tomorrow)) continue;
    final section = isOverdue(t, now)
        ? TodaySection.overdue
        : isAtc(t)
        ? TodaySection.payments
        : (t.dueAt != null && !t.allDay)
        ? TodaySection.timed
        : TodaySection.anytime;
    buckets[section]!.add(t);
  }

  buckets[TodaySection.overdue]!.sort(_byDueThenPriority);
  buckets[TodaySection.timed]!.sort(_byDueThenPriority);
  buckets[TodaySection.payments]!.sort(_byDueThenPriority);
  buckets[TodaySection.anytime]!.sort(_byPriorityThenAge);

  return {
    for (final e in buckets.entries)
      if (e.value.isNotEmpty) e.key: e.value,
  };
}

int _byDueThenPriority(Task a, Task b) {
  final byDue = (a.dueAt ?? 0).compareTo(b.dueAt ?? 0);
  return byDue != 0 ? byDue : _byPriorityThenAge(a, b);
}

int _byPriorityThenAge(Task a, Task b) {
  final byPriority = b.priority.compareTo(a.priority); // high first
  return byPriority != 0 ? byPriority : a.id.compareTo(b.id); // UUIDv7 = age
}

// ─────────────────────────────── Upcoming ──────────────────────────────────

/// Open tasks due in the 7 days after today, grouped by local day.
/// Days without tasks are left out.
Map<DateTime, List<Task>> upcomingByDay(List<Task> tasks, DateTime now) {
  final from = startOfDay(now).add(const Duration(days: 1));
  final to = from.add(const Duration(days: 7));
  final byDay = <DateTime, List<Task>>{};
  for (final t in tasks.where((t) => isOpen(t) && t.dueAt != null)) {
    final due = localDue(t);
    if (due.isBefore(from) || !due.isBefore(to)) continue;
    byDay.putIfAbsent(startOfDay(due), () => []).add(t);
  }
  for (final list in byDay.values) {
    list.sort(_byDueThenPriority);
  }
  final days = byDay.keys.toList()..sort();
  return {for (final d in days) d: byDay[d]!};
}

// ─────────────────────────────── Domains ───────────────────────────────────

const domainOrder = [
  'mind',
  'money',
  'health',
  'people',
  'work',
  'soul',
  'vault',
];

/// All open tasks grouped by domain, soonest due first (undated last).
Map<String, List<Task>> tasksByDomain(List<Task> tasks) {
  final groups = <String, List<Task>>{};
  for (final t in tasks.where(isOpen)) {
    groups.putIfAbsent(t.domain, () => []).add(t);
  }
  for (final list in groups.values) {
    list.sort((a, b) {
      if (a.dueAt == null || b.dueAt == null) {
        if (a.dueAt != b.dueAt) return a.dueAt == null ? 1 : -1;
        return _byPriorityThenAge(a, b);
      }
      return _byDueThenPriority(a, b);
    });
  }
  int rank(String d) {
    final i = domainOrder.indexOf(d);
    return i < 0 ? domainOrder.length : i;
  }

  final keys = groups.keys.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  return {for (final k in keys) k: groups[k]!};
}

// ──────────────────────────────── Repeat ───────────────────────────────────

enum RepeatFreq { daily, weekly, monthly }

/// The supported RRULE subset: FREQ=DAILY|WEEKLY|MONTHLY;INTERVAL=n
/// (+ BYMONTHDAY for monthly).
class RepeatRule {
  const RepeatRule(this.freq, {this.interval = 1, this.monthDay});

  final RepeatFreq freq;
  final int interval;
  final int? monthDay;

  /// Builds a rule anchored on [due] (monthly rules remember the day).
  factory RepeatRule.from(RepeatFreq freq, DateTime due, {int interval = 1}) =>
      RepeatRule(
        freq,
        interval: interval,
        monthDay: freq == RepeatFreq.monthly ? due.day : null,
      );

  static RepeatRule? parse(String? rrule) {
    if (rrule == null || rrule.isEmpty) return null;
    final parts = {
      for (final p in rrule.split(';'))
        if (p.contains('=')) p.split('=')[0].toUpperCase(): p.split('=')[1],
    };
    final freq = switch (parts['FREQ']?.toUpperCase()) {
      'DAILY' => RepeatFreq.daily,
      'WEEKLY' => RepeatFreq.weekly,
      'MONTHLY' => RepeatFreq.monthly,
      _ => null,
    };
    if (freq == null) return null;
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    return RepeatRule(
      freq,
      interval: interval < 1 ? 1 : interval,
      monthDay: int.tryParse(parts['BYMONTHDAY'] ?? ''),
    );
  }

  String format() => [
    'FREQ=${freq.name.toUpperCase()}',
    if (interval != 1) 'INTERVAL=$interval',
    if (monthDay != null) 'BYMONTHDAY=$monthDay',
  ].join(';');

  /// The occurrence after [from], keeping the time of day.
  DateTime after(DateTime from) {
    switch (freq) {
      case RepeatFreq.daily:
        return _addDays(from, interval);
      case RepeatFreq.weekly:
        return _addDays(from, 7 * interval);
      case RepeatFreq.monthly:
        final total = from.month - 1 + interval;
        final year = from.year + total ~/ 12;
        final month = total % 12 + 1;
        final day = _clampDay(year, month, monthDay ?? from.day);
        return DateTime(year, month, day, from.hour, from.minute);
    }
  }

  /// First occurrence after [due] that is on or after the start of [now]'s
  /// day — completing a long-overdue task doesn't create a backlog.
  DateTime nextOccurrence(DateTime due, DateTime now) {
    var next = after(due);
    final today = startOfDay(now);
    while (next.isBefore(today)) {
      next = after(next);
    }
    return next;
  }

  /// "Every week", "Every 3 days" — in the app's language.
  String describe() => switch (freq) {
    RepeatFreq.daily => l10nNow.tkEveryDay(interval),
    RepeatFreq.weekly => l10nNow.tkEveryWeek(interval),
    RepeatFreq.monthly => l10nNow.tkEveryMonth(interval),
  };

  // Calendar arithmetic (DST-safe: build from date parts, not Durations).
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  static int _clampDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return day > last ? last : day;
  }
}

// ──────────────────────────────── Snooze ───────────────────────────────────

enum SnoozeOption { tonight, tomorrow }

/// Snooze targets (PBI-009 grooming): tonight 20:00 (or +1 h if later),
/// tomorrow 09:00.
DateTime snoozeTarget(SnoozeOption option, DateTime now) {
  switch (option) {
    case SnoozeOption.tonight:
      final eight = DateTime(now.year, now.month, now.day, 20);
      return now.isBefore(eight) ? eight : now.add(const Duration(hours: 1));
    case SnoozeOption.tomorrow:
      return DateTime(now.year, now.month, now.day + 1, 9);
  }
}
