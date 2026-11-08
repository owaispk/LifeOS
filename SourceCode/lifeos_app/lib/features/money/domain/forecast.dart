// Monthly Money Forecast (PBI-019) — pure, no database, no Flutter.
import '../../../data/db/app_database.dart';
import '../../atc/domain/atc_schedule.dart';
import 'money_rules.dart';

enum ForecastStatus { upcoming, paid, overdue }

class ForecastItem {
  const ForecastItem({
    required this.title,
    required this.due,
    required this.amountMinor,
    required this.estimated,
    required this.status,
    required this.projected,
    this.paymentId,
    this.ruleId,
  });

  final String title;
  final DateTime due;

  /// Null when the amount isn't known yet ("amount pending").
  final int? amountMinor;

  /// Amount is a learned average ("~").
  final bool estimated;
  final ForecastStatus status;

  /// From an active rule, not generated yet (PBI-019 AC3).
  final bool projected;
  final String? paymentId;
  final String? ruleId;
}

class Forecast {
  const Forecast({
    required this.month,
    required this.items,
    required this.totalMinor,
    required this.paidMinor,
    this.salaryPercent,
  });

  final DateTime month;
  final List<ForecastItem> items;
  final int totalMinor;
  final int paidMinor;

  /// Fixed payments as a whole percent of salary (AC4), if salary is set.
  final int? salaryPercent;

  /// Always total − paid (AC1).
  int get remainingMinor => totalMinor - paidMinor;
}

/// The forecast for [month]: generated payments plus active rules'
/// not-yet-generated occurrences, each counted once.
Forecast forecastFor(
  DateTime month, {
  required List<AtcRule> rules,
  required List<Payment> payments,
  required DateTime now,
  int? salaryMinor,
  int? salaryDay,
}) {
  final m = monthStart(month);
  final next = addMonths(m, 1);
  final today = DateTime(now.year, now.month, now.day);
  final items = <ForecastItem>[];
  final generatedDueByRule = <String, Set<String>>{};
  final generatedCountByRule = <String, int>{};

  for (final p in payments) {
    if (p.deletedAt != null) continue;
    if (p.atcRuleId != null) {
      generatedDueByRule.putIfAbsent(p.atcRuleId!, () => {}).add(p.dueDate);
      generatedCountByRule[p.atcRuleId!] =
          (generatedCountByRule[p.atcRuleId!] ?? 0) + 1;
    }
    if (p.status == 'skipped') continue;
    final due = parseIsoDate(p.dueDate);
    if (due.isBefore(m) || !due.isBefore(next)) continue;
    final status = p.status == 'paid'
        ? ForecastStatus.paid
        : due.isBefore(today)
        ? ForecastStatus
              .overdue // AC2
        : ForecastStatus.upcoming;
    items.add(
      ForecastItem(
        title: p.title,
        due: due,
        amountMinor: p.amountMinor,
        estimated: false,
        status: status,
        projected: false,
        paymentId: p.id,
        ruleId: p.atcRuleId,
      ),
    );
  }

  for (final r in rules) {
    if (r.status != 'active' || r.deletedAt != null) continue;
    var count = generatedCountByRule[r.id] ?? 0;
    final from = m.isBefore(today) ? today : m; // never projects the past
    for (final due in occurrencesFrom(r, from)) {
      if (!due.isBefore(next)) break;
      if (generatedDueByRule[r.id]?.contains(isoDate(due)) ?? false) continue;
      if (r.installmentTotal != null && count >= r.installmentTotal!) break;
      count++;
      items.add(
        ForecastItem(
          title: r.name,
          due: due,
          amountMinor: r.amountMinor ?? r.amountAvgMinor,
          estimated: r.amountMinor == null && r.amountAvgMinor != null,
          status: ForecastStatus.upcoming,
          projected: true,
          ruleId: r.id,
        ),
      );
      if (r.cycle == 'once') break;
    }
  }

  // Salary-aware: the month starts at payday and wraps around.
  int order(ForecastItem i) {
    final d = i.due.day;
    return salaryDay == null || d >= salaryDay ? d : d + 31;
  }

  items.sort((a, b) {
    final byDay = order(a).compareTo(order(b));
    return byDay != 0 ? byDay : a.title.compareTo(b.title);
  });

  final total = items.fold<int>(0, (s, i) => s + (i.amountMinor ?? 0));
  final paid = items
      .where((i) => i.status == ForecastStatus.paid)
      .fold<int>(0, (s, i) => s + (i.amountMinor ?? 0));
  final percent = salaryMinor == null || salaryMinor <= 0
      ? null
      : ((total * 200) ~/ salaryMinor + 1) ~/ 2; // half-up, integers only

  return Forecast(
    month: m,
    items: items,
    totalMinor: total,
    paidMinor: paid,
    salaryPercent: percent,
  );
}
