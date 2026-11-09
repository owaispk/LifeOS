// Pure Money-light logic for PBI-018 — no database (display names via l10nNow).
import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';

// ─────────────────────────────── Dates ─────────────────────────────────────

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

/// Calendar-safe month arithmetic (day is always 1).
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// 'YYYY-MM-DD' — how `spent_on` / date columns are stored.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseIsoDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

bool inMonth(Expense e, DateTime month) {
  final d = parseIsoDate(e.spentOn);
  return d.year == month.year && d.month == month.month;
}

// ─────────────────────────────── Delta ─────────────────────────────────────

enum DeltaKind { none, newSpend, up, down, same }

/// Change vs last month. Never divides by zero: last month 0 → [newSpend]
/// (or [none] when both are 0).
class SpendDelta {
  const SpendDelta(this.kind, [this.percent = 0]);

  final DeltaKind kind;

  /// Whole-percent magnitude (always ≥ 0) for [up] / [down].
  final int percent;

  factory SpendDelta.compare(int thisMonth, int lastMonth) {
    if (lastMonth == 0) {
      return SpendDelta(thisMonth == 0 ? DeltaKind.none : DeltaKind.newSpend);
    }
    final diff = thisMonth - lastMonth;
    if (diff == 0) return const SpendDelta(DeltaKind.same);
    // Integer rounding to nearest whole percent, no floats.
    final pct = ((diff.abs() * 200) ~/ lastMonth + 1) ~/ 2;
    return SpendDelta(diff > 0 ? DeltaKind.up : DeltaKind.down, pct);
  }

  @override
  bool operator ==(Object other) =>
      other is SpendDelta && other.kind == kind && other.percent == percent;

  @override
  int get hashCode => Object.hash(kind, percent);

  @override
  String toString() => 'SpendDelta($kind, $percent%)';
}

// ──────────────────────────── Breakdown ────────────────────────────────────

/// System categories with a fixed colour slot (PBI-018 grooming); every
/// other category shares the neutral "other" colour.
const categorySlots = [
  'rent',
  'fees',
  'utilities',
  'internet',
  'mobile',
  'installment',
  'subscription',
];

/// Colour slot for a category: 0–6 for the named system categories,
/// null for "Other", custom and uncategorised (neutral grey).
int? colorSlotFor(Category? c) {
  final i = categorySlots.indexOf(c?.systemKey ?? '');
  return i < 0 ? null : i;
}

/// Display name for [c]: system categories (seeded in English) show in the
/// app's language; custom ones as typed; none → "Uncategorised".
String categoryName(Category? c) {
  final l = l10nNow;
  if (c == null) return l.mnUncategorised;
  return switch (c.systemKey) {
    'rent' => l.mnCatRent,
    'fees' => l.mnCatFees,
    'utilities' => l.mnCatUtilities,
    'internet' => l.mnCatInternet,
    'mobile' => l.mnCatMobile,
    'installment' => l.mnCatInstallment,
    'subscription' => l.mnCatSubscription,
    'other' => l.mnCatOther,
    _ => c.name,
  };
}

class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.amountMinor,
    required this.colorSlot,
  });

  /// null = uncategorised.
  final String? categoryId;
  final String name;
  final String icon;
  final int amountMinor;
  final int? colorSlot;

  /// Share of [total] in whole percent (rounded).
  int sharePercent(int total) =>
      total == 0 ? 0 : ((amountMinor * 200) ~/ total + 1) ~/ 2;
}

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.totalMinor,
    required this.lastMonthTotalMinor,
    required this.delta,
    required this.slices,
    required this.expenses,
  });

  final DateTime month;
  final int totalMinor;
  final int lastMonthTotalMinor;
  final SpendDelta delta;

  /// Largest first; their amounts always sum to [totalMinor].
  final List<CategorySlice> slices;

  /// This month's expenses, newest first.
  final List<Expense> expenses;
}

/// Everything the Month Overview shows for [month].
MonthSummary summarize(
  List<Expense> all,
  List<Category> categories,
  DateTime month,
) {
  final m = monthStart(month);
  final live = all.where((e) => e.deletedAt == null);
  final current = live.where((e) => inMonth(e, m)).toList()
    ..sort((a, b) {
      final byDate = b.spentOn.compareTo(a.spentOn);
      return byDate != 0 ? byDate : b.id.compareTo(a.id); // UUIDv7 = age
    });
  final previous = live.where((e) => inMonth(e, addMonths(m, -1)));

  final total = current.fold<int>(0, (s, e) => s + e.amountMinor);
  final lastTotal = previous.fold<int>(0, (s, e) => s + e.amountMinor);

  final byId = {for (final c in categories) c.id: c};
  final sums = <String?, int>{};
  for (final e in current) {
    final key = byId.containsKey(e.categoryId) ? e.categoryId : null;
    sums[key] = (sums[key] ?? 0) + e.amountMinor;
  }
  final slices =
      [
        for (final entry in sums.entries)
          CategorySlice(
            categoryId: entry.key,
            name: categoryName(byId[entry.key]),
            icon: byId[entry.key]?.icon ?? '❔',
            amountMinor: entry.value,
            colorSlot: colorSlotFor(byId[entry.key]),
          ),
      ]..sort((a, b) {
        final byAmount = b.amountMinor.compareTo(a.amountMinor);
        return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
      });

  return MonthSummary(
    month: m,
    totalMinor: total,
    lastMonthTotalMinor: lastTotal,
    delta: SpendDelta.compare(total, lastTotal),
    slices: slices,
    expenses: current,
  );
}
