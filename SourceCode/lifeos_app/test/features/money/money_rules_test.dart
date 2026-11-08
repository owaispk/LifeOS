// PBI-018: pure Money rules — totals (AC1), breakdown sums (AC2),
// delta without divide-by-zero (AC3), month maths (AC4).
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/money/domain/money_rules.dart';

var _seq = 0;
Expense expense(
  int amountMinor,
  String spentOn, {
  String? categoryId,
  int? deletedAt,
}) {
  _seq++;
  return Expense(
    id: 'e-${_seq.toString().padLeft(4, '0')}',
    userId: 'u',
    updatedAt: 0,
    version: 1,
    deletedAt: deletedAt,
    categoryId: categoryId,
    amountMinor: amountMinor,
    currency: 'PKR',
    spentOn: spentOn,
  );
}

Category category(String id, String name, {String? systemKey}) => Category(
  id: id,
  userId: 'u',
  updatedAt: 0,
  version: 1,
  name: name,
  icon: '•',
  kind: 'expense',
  systemKey: systemKey,
);

final cats = [
  category('c-rent', 'Rent', systemKey: 'rent'),
  category('c-util', 'Utilities', systemKey: 'utilities'),
  category('c-other', 'Other', systemKey: 'other'),
  category('c-gym', 'Gym'), // custom
];

final nov = DateTime(2026, 11);

void main() {
  group('dates', () {
    test('isoDate / parseIsoDate round-trip', () {
      expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
      expect(parseIsoDate('2026-03-07'), DateTime(2026, 3, 7));
    });

    test('addMonths crosses year boundaries', () {
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(monthStart(DateTime(2026, 11, 30, 23)), DateTime(2026, 11));
    });
  });

  group('SpendDelta (AC3)', () {
    test('last month 0 → New (no divide by zero)', () {
      expect(
        SpendDelta.compare(125000, 0),
        const SpendDelta(DeltaKind.newSpend),
      );
    });
    test('both months 0 → none', () {
      expect(SpendDelta.compare(0, 0), const SpendDelta(DeltaKind.none));
    });
    test('up / down / same with whole-percent rounding', () {
      expect(
        SpendDelta.compare(112000, 100000),
        const SpendDelta(DeltaKind.up, 12),
      );
      expect(
        SpendDelta.compare(75000, 100000),
        const SpendDelta(DeltaKind.down, 25),
      );
      expect(SpendDelta.compare(5000, 5000), const SpendDelta(DeltaKind.same));
      expect(
        SpendDelta.compare(0, 5000),
        const SpendDelta(DeltaKind.down, 100),
      );
      // Rounded to the nearest whole percent: 1/3 → 33%, 2/3 → 67%,
      // 0.5% → 1% (half-up), 0.4% → 0%.
      expect(SpendDelta.compare(400, 300).percent, 33);
      expect(SpendDelta.compare(500, 300).percent, 67);
      expect(SpendDelta.compare(20100, 20000).percent, 1);
      expect(
        SpendDelta.compare(10040, 10000),
        const SpendDelta(DeltaKind.up, 0),
      );
    });
  });

  group('summarize', () {
    test('AC1: a Rs 1,250 expense adds 125000 to the month total', () {
      final s = summarize([expense(125000, '2026-11-08')], cats, nov);
      expect(s.totalMinor, 125000);
      expect(s.expenses, hasLength(1));
    });

    test('AC2: category totals add up to the month total', () {
      final all = [
        expense(4500000, '2026-11-01', categoryId: 'c-rent'),
        expense(485000, '2026-11-12', categoryId: 'c-util'),
        expense(120000, '2026-11-14', categoryId: 'c-util'),
        expense(99999, '2026-11-15', categoryId: 'c-gym'),
        expense(1250, '2026-11-15'), // uncategorised
        expense(777, '2026-11-16', categoryId: 'deleted-category'),
        // Not this month / deleted:
        expense(100, '2026-10-31', categoryId: 'c-rent'),
        expense(100, '2026-12-01', categoryId: 'c-rent'),
        expense(100, '2026-11-20', categoryId: 'c-rent', deletedAt: 1),
      ];
      final s = summarize(all, cats, nov);
      final sliceSum = s.slices.fold<int>(0, (t, x) => t + x.amountMinor);
      expect(sliceSum, s.totalMinor);
      expect(s.totalMinor, 4500000 + 485000 + 120000 + 99999 + 1250 + 777);

      // Largest first; unknown category ids fold into "Uncategorised".
      expect(s.slices.map((x) => x.name), [
        'Rent',
        'Utilities',
        'Gym',
        'Uncategorised',
      ]);
      expect(s.slices.last.amountMinor, 1250 + 777);
    });

    test('colour follows the category, not its rank', () {
      final s = summarize(
        [
          expense(100, '2026-11-01', categoryId: 'c-util'),
          expense(900, '2026-11-02', categoryId: 'c-rent'),
          expense(50, '2026-11-03', categoryId: 'c-other'),
          expense(40, '2026-11-03', categoryId: 'c-gym'),
        ],
        cats,
        nov,
      );
      final slot = {for (final x in s.slices) x.name: x.colorSlot};
      expect(slot['Rent'], 0);
      expect(slot['Utilities'], 2);
      expect(slot['Other'], isNull); // neutral grey
      expect(slot['Gym'], isNull); // custom → neutral grey
    });

    test('expenses are newest first; delta compares with last month', () {
      final s = summarize(
        [
          expense(100000, '2026-10-05'),
          expense(30000, '2026-11-02'),
          expense(82000, '2026-11-07'),
        ],
        cats,
        nov,
      );
      expect(s.expenses.map((e) => e.spentOn), ['2026-11-07', '2026-11-02']);
      expect(s.lastMonthTotalMinor, 100000);
      expect(s.delta, const SpendDelta(DeltaKind.up, 12));
    });

    test('share percentages', () {
      const slice = CategorySlice(
        categoryId: null,
        name: 'x',
        icon: '',
        amountMinor: 1,
        colorSlot: null,
      );
      expect(slice.sharePercent(3), 33);
      expect(slice.sharePercent(0), 0);
    });
  });
}
