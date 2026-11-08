// PBI-019: forecast maths (AC1–AC5), pure.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/ids.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/money/domain/forecast.dart';

final now = DateTime(2026, 11, 8, 10);
final nov = DateTime(2026, 11);

AtcRule rule(
  String name, {
  int? day = 1,
  int? amount,
  int? avg,
  String status = 'active',
  int? total,
  DateTime? created,
}) => AtcRule(
  id: IdGenerator(
    nowMs: () => (created ?? DateTime(2026, 9, 1)).millisecondsSinceEpoch,
  ).next(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  kind: 'fixed',
  name: name,
  amountMinor: amount,
  amountAvgMinor: avg,
  dueDay: day,
  cycle: 'monthly',
  skipMonths: '[]',
  installmentTotal: total,
  remindDaysBefore: 5,
  status: status,
  stats: '{}',
);

var _p = 0;
Payment payment(
  String title,
  String due, {
  int? amount,
  String status = 'upcoming',
  String? ruleId,
}) => Payment(
  id: 'p${_p++}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  atcRuleId: ruleId,
  title: title,
  amountMinor: amount,
  currency: 'PKR',
  dueDate: due,
  periodMonth: '${due.substring(0, 7)}-01',
  status: status,
);

void main() {
  test('AC1/AC2: totals add up; unpaid past due is Overdue', () {
    final f = forecastFor(
      nov,
      rules: const [],
      payments: [
        payment('Rent', '2026-11-01', amount: 4500000, status: 'paid'),
        payment('Electricity', '2026-11-05', amount: 485000), // overdue
        payment('School fee', '2026-11-20', amount: 1200000),
        payment('December rent', '2026-12-01', amount: 4500000),
      ],
      now: now,
    );
    expect(f.items.map((i) => (i.title, i.status)), [
      ('Rent', ForecastStatus.paid),
      ('Electricity', ForecastStatus.overdue),
      ('School fee', ForecastStatus.upcoming),
    ]);
    expect(f.totalMinor, 6185000);
    expect(f.paidMinor, 4500000);
    expect(f.remainingMinor, f.totalMinor - f.paidMinor);
  });

  test('AC3: projected items are added once, never double-counted', () {
    final rent = rule('Rent', day: 25, amount: 4500000);
    final internet = rule('Internet', day: 15, amount: 300000);
    // Internet's November one is already generated; rent's is not.
    final f = forecastFor(
      nov,
      rules: [rent, internet],
      payments: [
        payment('Internet', '2026-11-15', amount: 300000, ruleId: internet.id),
      ],
      now: now,
    );
    expect(f.items.map((i) => (i.title, i.projected)), [
      ('Internet', false),
      ('Rent', true),
    ]);
    expect(f.totalMinor, 4800000);
  });

  test(
    'projections skip the past, paused rules, and finished installments',
    () {
      final committee = rule('Committee', day: 22, amount: 1000000, total: 1);
      final f = forecastFor(
        nov,
        rules: [
          rule('Rent', day: 1, amount: 4500000), // 1 Nov already passed
          rule('Gym', day: 20, amount: 500000, status: 'paused'),
          committee,
        ],
        payments: [
          payment(
            'Committee',
            '2026-10-22',
            amount: 1000000,
            status: 'paid',
            ruleId: committee.id,
          ),
        ],
        now: now,
      );
      expect(f.items, isEmpty);
    },
  );

  test('future months project every active rule; averages are "~"', () {
    final f = forecastFor(
      DateTime(2026, 12),
      rules: [
        rule('Rent', day: 1, amount: 4500000),
        rule('Electricity', day: 12, avg: 520000),
        rule('Water', day: 20),
      ],
      payments: const [],
      now: now,
    );
    expect(f.items.map((i) => (i.title, i.amountMinor, i.estimated)), [
      ('Rent', 4500000, false),
      ('Electricity', 520000, true),
      ('Water', null, false),
    ]);
    expect(f.totalMinor, 5020000, reason: 'unknown amounts count as 0');
  });

  test('AC4: salary-aware percentage and order', () {
    final f = forecastFor(
      nov,
      rules: const [],
      payments: [
        payment('Rent', '2026-11-01', amount: 4500000),
        payment('Fee', '2026-11-10', amount: 1200000),
        payment('Internet', '2026-11-28', amount: 450000),
      ],
      now: DateTime(2026, 10, 30),
      salaryMinor: 15000000,
      salaryDay: 25,
    );
    // 61,500 / 150,000 = 41%.
    expect(f.salaryPercent, 41);
    expect(f.items.map((i) => i.title), ['Internet', 'Rent', 'Fee']);

    final half = forecastFor(
      nov,
      rules: const [],
      payments: [payment('X', '2026-11-20', amount: 100)],
      now: now,
      salaryMinor: 200,
    );
    expect(half.salaryPercent, 50);
    expect(
      forecastFor(
        nov,
        rules: const [],
        payments: const [],
        now: now,
      ).salaryPercent,
      isNull,
    );
  });

  test('skipped and deleted payments are ignored', () {
    final f = forecastFor(
      nov,
      rules: const [],
      payments: [
        payment('Skipped', '2026-11-20', amount: 100, status: 'skipped'),
      ],
      now: now,
    );
    expect(f.items, isEmpty);
  });
}
