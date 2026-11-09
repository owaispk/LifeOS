// Home-screen widget snapshot (PBI-033) — pure, no database, no platform.
// The Dart side computes everything; the native side only renders.
import 'dart:convert';

import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../../money/domain/money_rules.dart' show isoDate, parseIsoDate;
import '../../score/domain/life_score.dart';
import '../../tasks/domain/task_rules.dart';

/// The widget shows at most this many task lines (PBI-033).
const widgetTaskCap = 4;

/// One tappable task line: pre-rendered text + the task id to deep-link to.
class WidgetTaskLine {
  const WidgetTaskLine(this.id, this.text);
  final String id;
  final String text;

  Map<String, String> toJson() => {'id': id, 'text': text};
}

/// What one day of the widget renders. [tomorrow] in [WidgetSnapshot] is
/// the same data recomputed for just after midnight, so the Android
/// provider can swap at the date change without the app running (AC3).
class WidgetDayData {
  const WidgetDayData({
    required this.score,
    required this.counts,
    required this.tasks,
    required this.more,
    required this.payment,
    required this.paymentTaskId,
    required this.empty,
  });

  final int score;

  /// "5 tasks · 2 due" — all the small sizes show besides the ring.
  final String counts;

  /// Up to [widgetTaskCap] lines, ⚡ ATC payments first, then by time.
  final List<WidgetTaskLine> tasks;

  /// "+N more", or '' when everything fits.
  final String more;

  /// "⚡ Electricity ~Rs 4,300 · Thu", or '' without an upcoming payment.
  final String payment;

  /// The payment's task to deep-link to; '' when it has none.
  final String paymentTaskId;

  /// "All clear today ✨", or '' when there is content.
  final String empty;

  Map<String, Object> toJson() => {
    'score': score,
    'counts': counts,
    'tasks': [for (final t in tasks) t.toJson()],
    'more': more,
    'payment': payment,
    'paymentTask': paymentTaskId,
    'empty': empty,
  };
}

/// Everything the native widget needs, serialised in one place so the
/// widget and the Home dashboard can never disagree (grooming note).
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.day,
    required this.details,
    required this.rtl,
    required this.today,
    required this.tomorrow,
  });

  /// ISO date the snapshot was built on; the native side renders
  /// [tomorrow] once its clock has moved past this day.
  final String day;

  /// "Show details on widget" (PBI-033 AC5): when false, [today] and
  /// [tomorrow] carry no titles or amounts — only the ring and counts.
  final bool details;

  /// Urdu lays the widget out right-to-left.
  final bool rtl;

  final WidgetDayData today;
  final WidgetDayData tomorrow;

  String toJsonString() => jsonEncode({
    'v': 1,
    'day': day,
    'details': details,
    'rtl': rtl,
    'today': today.toJson(),
    'tomorrow': tomorrow.toJson(),
  });
}

/// Builds the snapshot from live data. Reads words through [l10nNow] and
/// amounts through the global region, exactly like the dashboard.
WidgetSnapshot buildWidgetSnapshot({
  required List<Task> tasks,
  required List<Payment> payments,
  required List<Document> documents,
  required DateTime now,
  ScoreWeights weights = ScoreWeights.v1,
  bool details = true,
  bool rtl = false,
}) {
  WidgetDayData dayData(DateTime at) => _dayData(
    tasks: tasks,
    payments: payments,
    documents: documents,
    now: at,
    weights: weights,
    details: details,
  );
  // 00:05, not 00:00: clearly inside the next day for date comparisons.
  final next = DateTime(now.year, now.month, now.day + 1, 0, 5);
  return WidgetSnapshot(
    day: isoDate(now),
    details: details,
    rtl: rtl,
    today: dayData(now),
    tomorrow: dayData(next),
  );
}

WidgetDayData _dayData({
  required List<Task> tasks,
  required List<Payment> payments,
  required List<Document> documents,
  required DateTime now,
  required ScoreWeights weights,
  required bool details,
}) {
  final l = l10nNow;
  final score = computeLifeScore(
    tasks: tasks,
    payments: payments,
    documents: documents,
    now: now,
    weights: weights,
  ).score;

  // ⚡ ATC payments first, then the rest by time (PBI-033 description).
  final sections = todaySections(tasks, now);
  final ordered = [
    ...?sections[TodaySection.payments],
    ...?sections[TodaySection.overdue],
    ...?sections[TodaySection.timed],
    ...?sections[TodaySection.anytime],
  ];
  final lines = [
    for (final t in ordered.take(widgetTaskCap)) WidgetTaskLine(t.id, _line(t)),
  ];
  final more = ordered.length > widgetTaskCap
      ? l.wgMore('${ordered.length - widgetTaskCap}')
      : '';

  // Next unpaid payment by due date — overdue ones stay at the front.
  final unpaid =
      payments
          .where(
            (p) =>
                p.deletedAt == null &&
                p.status != 'paid' &&
                p.status != 'skipped',
          )
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final nextPay = unpaid.firstOrNull;
  final payLine = nextPay == null
      ? ''
      : nextPay.amountMinor == null
      ? l.wgPaymentLineNoAmount(nextPay.title, _dayLabel(nextPay.dueDate, now))
      : l.wgPaymentLine(
          nextPay.title,
          Money.format(nextPay.amountMinor!),
          _dayLabel(nextPay.dueDate, now),
        );

  final due = unpaid
      .where((p) => !parseIsoDate(p.dueDate).isAfter(startOfDay(now)))
      .length;
  final counts = due == 0
      ? l.wgTasksShort(ordered.length)
      : '${l.wgTasksShort(ordered.length)} · ${l.wgDueShort(due)}';

  final clear = ordered.isEmpty && nextPay == null;
  if (!details) {
    // Privacy (AC5): only the ring and counts, never titles or amounts.
    return WidgetDayData(
      score: score,
      counts: counts,
      tasks: const [],
      more: '',
      payment: '',
      paymentTaskId: '',
      empty: clear ? l.wgAllClear : '',
    );
  }
  return WidgetDayData(
    score: score,
    counts: counts,
    tasks: lines,
    more: more,
    payment: payLine,
    paymentTaskId: nextPay?.taskId ?? '',
    empty: clear ? l.wgAllClear : '',
  );
}

/// "⚡ Electricity bill", "4:00 PM · Standup", or just the title.
String _line(Task t) {
  if (isAtc(t)) return '⚡ ${t.title}';
  if (t.dueAt != null && !t.allDay) return '${formatTime(localDue(t))} · ${t.title}';
  return t.title;
}

/// "Today", "Tomorrow", "Thu" within the week, "9 Nov" beyond, and
/// "3d late" when overdue — short enough for one widget line.
String _dayLabel(String iso, DateTime now) {
  final due = parseIsoDate(iso);
  final days = due.difference(startOfDay(now)).inDays;
  if (days < 0) return l10nNow.hmWasDueAgo(-days);
  if (days == 0) return l10nNow.today;
  if (days == 1) return l10nNow.tomorrow;
  if (days < 7) return weekdayShort(due);
  return dayMonth(due);
}
