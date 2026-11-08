// Auto Task Creator scheduling (PBI-013) — pure, no database, no Flutter.
import 'dart:convert';

import '../../../core/ids.dart';
import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../money/domain/money_rules.dart' show isoDate, parseIsoDate;

/// Free plan limit on active rules (PBI-013 AC6; Premium is PBI-029).
const freeTierRuleLimit = 3;

int monthsPerCycle(String cycle) => switch (cycle) {
  'quarterly' => 3,
  'semester' => 6,
  'yearly' => 12,
  _ => 1, // monthly, once
};

/// The day [dueDay] of a month, clamped to its last day (31 → Feb 28/29,
/// Apr 30) — AC5.
DateTime clampedDay(int year, int month, int dueDay) {
  final last = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, dueDay > last ? last : dueDay);
}

List<int> skipMonthsOf(AtcRule r) {
  try {
    return (jsonDecode(r.skipMonths) as List).cast<int>();
  } on Object {
    return const [];
  }
}

/// The month cycles are counted from: the rule's creation month (UUIDv7).
DateTime anchorMonth(AtcRule r) {
  final created = DateTime.fromMillisecondsSinceEpoch(
    IdGenerator.timestampOf(r.id),
  );
  return DateTime(created.year, created.month);
}

/// Due dates of [rule] in calendar order, starting with the first one on or
/// after [from]. Skip months are jumped over (AC3). Rules without a due day
/// never produce occurrences.
Iterable<DateTime> occurrencesFrom(AtcRule rule, DateTime from) sync* {
  final day = rule.dueDay;
  if (day == null) return;
  final step = monthsPerCycle(rule.cycle);
  final anchor = anchorMonth(rule);
  final skip = skipMonthsOf(rule);
  final start = DateTime(from.year, from.month, from.day);

  // First cycle month at or before `from`'s month.
  var k =
      ((start.year - anchor.year) * 12 + start.month - anchor.month) ~/ step;
  if (k < 0) k = 0;
  for (var guard = 0; guard < 600; guard++, k++) {
    final m = DateTime(anchor.year, anchor.month + k * step);
    final due = clampedDay(m.year, m.month, day);
    if (due.isBefore(start)) continue;
    if (skip.contains(due.month)) continue;
    yield due;
  }
}

/// What the generator should create for one rule, or null.
class PlannedOccurrence {
  const PlannedOccurrence({
    required this.due,
    required this.title,
    required this.installmentNumber,
  });

  final DateTime due;
  final String title;

  /// 1-based installment number, or null for non-installment rules.
  final int? installmentNumber;
}

String occurrenceTitle(AtcRule rule, {int? installment}) {
  final amount = rule.amountMinor ?? rule.amountAvgMinor;
  final money = amount == null
      ? null
      : '${rule.amountMinor == null ? '~' : ''}${Money.format(amount)}';
  final parts = [rule.name, ?money];
  final base = parts.join(' — ');
  final total = rule.installmentTotal;
  return installment != null && total != null
      ? '$base ($installment of $total)'
      : base;
}

/// Keeps exactly one next occurrence per active rule (PBI-013 grooming):
/// - nothing generated yet → the first due date on or after today;
/// - the last generated due date has passed → the next one on or after
///   today (no back-fill after pauses or long absences, AC7);
/// - otherwise (the next one already exists) → nothing (idempotent, AC2).
/// [generatedCount] = occurrences already created for this rule.
PlannedOccurrence? planNext(
  AtcRule rule, {
  required DateTime today,
  required int generatedCount,
}) {
  if (rule.status != 'active' || rule.deletedAt != null) return null;
  final total = rule.installmentTotal;
  if (total != null && generatedCount >= total) return null;
  if (rule.cycle == 'once' && generatedCount > 0) return null;

  final day = DateTime(today.year, today.month, today.day);
  final last = rule.lastGeneratedPeriod == null
      ? null
      : parseIsoDate(rule.lastGeneratedPeriod!);
  if (last != null && !last.isBefore(day)) return null; // next one exists

  // Either nothing exists yet or the last one is in the past: the next
  // occurrence is the first on or after today (never a back-fill).
  final due = occurrencesFrom(rule, day).firstOrNull;
  if (due == null) return null;
  final n = total == null ? null : generatedCount + 1;
  return PlannedOccurrence(
    due: due,
    title: occurrenceTitle(rule, installment: n),
    installmentNumber: n,
  );
}

/// Cadence label for the rules list: "Monthly · 1st", "Quarterly · 5th",
/// "~10th–14th monthly" for learned bill patterns.
String cadenceLabel(AtcRule r) {
  if (r.kind == 'bill_pattern' && r.expectedWindow != null) {
    try {
      final w = jsonDecode(r.expectedWindow!) as Map<String, dynamic>;
      return '~${_ordinal(w['from'] as int)}–${_ordinal(w['to'] as int)} '
          'monthly';
    } on Object {
      // fall through
    }
  }
  final cycle = switch (r.cycle) {
    'quarterly' => 'Quarterly',
    'semester' => 'Every 6 months',
    'yearly' => 'Yearly',
    'once' => 'Once',
    _ => 'Monthly',
  };
  return r.dueDay == null ? cycle : '$cycle · ${_ordinal(r.dueDay!)}';
}

String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// "Created N tasks · M paid on time" for a rule's payments.
({int created, int paidOnTime}) ruleHistory(List<Payment> payments) {
  var onTime = 0;
  for (final p in payments) {
    if (p.status != 'paid' || p.paidAt == null) continue;
    final due = parseIsoDate(p.dueDate);
    final endOfDue = DateTime(due.year, due.month, due.day + 1);
    if (DateTime.fromMillisecondsSinceEpoch(p.paidAt!).isBefore(endOfDue)) {
      onTime++;
    }
  }
  return (created: payments.length, paidOnTime: onTime);
}

/// The reminder time for an occurrence: [remindDaysBefore] days before the
/// due date at 09:00 local.
DateTime reminderFor(DateTime due, int remindDaysBefore) =>
    DateTime(due.year, due.month, due.day - remindDaysBefore, 9);

String periodKey(DateTime due) => isoDate(due);
