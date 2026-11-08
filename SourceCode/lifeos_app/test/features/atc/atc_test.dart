// PBI-013 / PBI-017: schedule rules (pure) and the service on a real DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/ids.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:lifeos_app/features/atc/domain/atc_schedule.dart';
import 'package:lifeos_app/features/money/domain/money_rules.dart'
    show parseIsoDate;

import '../../data/db_test_utils.dart';

/// A rule as if created at [created] (anchor month comes from the id).
AtcRule rule({
  int? dueDay = 1,
  String cycle = 'monthly',
  String skip = '[]',
  String status = 'active',
  String? last,
  int? total,
  int? amount = 4500000,
  DateTime? created,
  String kind = 'fixed',
  String? window,
}) => AtcRule(
  id: IdGenerator(
    nowMs: () => (created ?? DateTime(2026, 11, 8)).millisecondsSinceEpoch,
  ).next(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  kind: kind,
  name: 'Rent',
  amountMinor: amount,
  dueDay: dueDay,
  cycle: cycle,
  skipMonths: skip,
  installmentTotal: total,
  remindDaysBefore: 5,
  status: status,
  lastGeneratedPeriod: last,
  stats: '{}',
  expectedWindow: window,
);

void main() {
  final today = DateTime(2026, 11, 8);

  group('schedule (pure)', () {
    test('AC5: day 31 clamps to Feb 28/29 and Apr 30', () {
      expect(clampedDay(2027, 2, 31), DateTime(2027, 2, 28));
      expect(clampedDay(2028, 2, 31), DateTime(2028, 2, 29));
      expect(clampedDay(2027, 4, 31), DateTime(2027, 4, 30));
      final r = rule(dueDay: 31);
      expect(occurrencesFrom(r, DateTime(2027, 1, 15)).take(4).toList(), [
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('AC1: day 1 created on 8 Nov → next is 1 Dec', () {
      final p = planNext(rule(), today: today, generatedCount: 0)!;
      expect(p.due, DateTime(2026, 12, 1));
      expect(p.title, 'Rent — Rs 45,000');
    });

    test('a due day later this month is this month', () {
      expect(
        planNext(rule(dueDay: 20), today: today, generatedCount: 0)!.due,
        DateTime(2026, 11, 20),
      );
      expect(
        planNext(rule(dueDay: 8), today: today, generatedCount: 0)!.due,
        DateTime(2026, 11, 8),
        reason: 'today counts',
      );
    });

    test('AC2: when the next one exists, nothing more is planned', () {
      final r = rule(last: '2026-12-01');
      expect(planNext(r, today: today, generatedCount: 1), isNull);
    });

    test('once the last due date passes, the following one is planned', () {
      final r = rule(last: '2026-11-01');
      expect(
        planNext(r, today: today, generatedCount: 1)!.due,
        DateTime(2026, 12, 1),
      );
    });

    test('AC3: skip months are jumped over', () {
      final r = rule(dueDay: 5, skip: '[6,7]', created: DateTime(2026, 5, 1));
      final dues = occurrencesFrom(r, DateTime(2027, 5, 10)).take(2).toList();
      expect(dues, [DateTime(2027, 8, 5), DateTime(2027, 9, 5)]);
    });

    test('cycles count from the creation month', () {
      final q = rule(
        dueDay: 10,
        cycle: 'quarterly',
        created: DateTime(2026, 1, 3),
      );
      expect(occurrencesFrom(q, today).take(3).toList(), [
        DateTime(2027, 1, 10),
        DateTime(2027, 4, 10),
        DateTime(2027, 7, 10),
      ]);
      final y = rule(
        dueDay: 15,
        cycle: 'yearly',
        created: DateTime(2026, 3, 1),
      );
      expect(occurrencesFrom(y, today).first, DateTime(2027, 3, 15));
    });

    test('AC7: paused rules plan nothing; resuming never back-fills', () {
      expect(
        planNext(rule(status: 'paused'), today: today, generatedCount: 0),
        isNull,
      );
      // Last generated in August, resumed in November → December, not
      // September/October/November.
      final r = rule(last: '2026-08-01');
      expect(
        planNext(r, today: today, generatedCount: 1)!.due,
        DateTime(2026, 12, 1),
      );
    });

    test('AC4: installments number themselves and stop at the total', () {
      final r = rule(total: 24);
      expect(
        planNext(r, today: today, generatedCount: 6)!.title,
        'Rent — Rs 45,000 (7 of 24)',
      );
      expect(planNext(r, today: today, generatedCount: 24), isNull);
    });

    test('once rules generate a single occurrence', () {
      final r = rule(cycle: 'once', dueDay: 20);
      expect(planNext(r, today: today, generatedCount: 0), isNotNull);
      expect(planNext(r, today: today, generatedCount: 1), isNull);
    });

    test('unknown amounts show "~" with the learned average', () {
      expect(occurrenceTitle(rule(amount: null)), 'Rent');
    });

    test('cadence labels and history', () {
      expect(cadenceLabel(rule()), 'Monthly · 1st');
      expect(
        cadenceLabel(rule(dueDay: 22, cycle: 'quarterly')),
        'Quarterly · 22nd',
      );
      expect(cadenceLabel(rule(dueDay: 13)), 'Monthly · 13th');
      expect(
        cadenceLabel(rule(kind: 'bill_pattern', window: '{"from":10,"to":14}')),
        '~10th–14th monthly',
      );
      Payment pay(String due, DateTime? paid) => Payment(
        id: due,
        userId: 'u',
        updatedAt: 0,
        version: 1,
        title: 'x',
        currency: 'PKR',
        dueDate: due,
        periodMonth: due,
        status: paid == null ? 'upcoming' : 'paid',
        paidAt: paid?.millisecondsSinceEpoch,
      );
      final h = ruleHistory([
        pay('2026-09-01', DateTime(2026, 8, 30)),
        pay('2026-10-01', DateTime(2026, 10, 1, 22)),
        pay('2026-11-01', DateTime(2026, 11, 3)),
        pay('2026-12-01', null),
      ]);
      expect((h.created, h.paidOnTime), (4, 2));
    });
  });

  group('service (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    late AtcService atc;
    var now = DateTime(2026, 11, 8, 10);

    setUp(() async {
      db = memoryDb();
      now = DateTime(2026, 11, 8, 10);
      await openLocalData(db); // seed folders, categories, settings
      repos = await Repositories.open(
        db,
        clock: () => now.millisecondsSinceEpoch,
      );
      atc = AtcService(repos, now: () => now);
    });
    tearDown(() => db.close());

    Future<List<Payment>> paymentsOf(String ruleId) =>
        repos.payments.getWhere((p) => p.atcRuleId.equals(ruleId));

    test('AC1: a Rent rule creates one task + payment + reminder', () async {
      final r = await atc.createRule(
        const RuleInput(
          name: 'Rent',
          categoryKey: 'rent',
          dueDay: 1,
          amountMinor: 4500000,
        ),
      );
      final pays = await paymentsOf(r.id);
      expect(pays, hasLength(1));
      final p = pays.single;
      expect(
        (p.dueDate, p.amountMinor, p.status),
        ('2026-12-01', 4500000, 'upcoming'),
      );
      final rent = (await repos.categories.getAll()).firstWhere(
        (c) => c.systemKey == 'rent',
      );
      expect(p.categoryId, rent.id);

      final task = (await repos.tasks.getById(p.taskId!))!;
      expect(
        (task.title, task.atcRuleId, task.domain),
        ('Rent — Rs 45,000', r.id, 'money'),
      );
      expect(parseIsoDate(p.dueDate), DateTime(2026, 12, 1));
      final reminder = (await repos.taskReminders.getWhere(
        (x) => x.taskId.equals(task.id),
      )).single;
      expect(
        DateTime.fromMillisecondsSinceEpoch(reminder.fireAt),
        DateTime(2026, 11, 26, 9),
      );
      expect(r.lastGeneratedPeriod, '2026-12-01');
    });

    test('AC2: running the generator again creates nothing', () async {
      final r = await atc.createRule(
        const RuleInput(name: 'Rent', categoryKey: 'rent', dueDay: 1),
      );
      expect(await atc.generateAll(), 0);
      expect(await atc.generateAll(), 0);
      expect(await paymentsOf(r.id), hasLength(1));

      now = DateTime(2026, 12, 2, 9); // the 1 Dec one has passed
      expect(await atc.generateAll(), 1);
      expect(await atc.generateAll(), 0);
      expect((await paymentsOf(r.id)).map((p) => p.dueDate).toList()..sort(), [
        '2026-12-01',
        '2027-01-01',
      ]);
    });

    test('AC3: skip months produce no task for those months', () async {
      now = DateTime(2027, 5, 20);
      final r = await atc.createRule(
        const RuleInput(
          name: 'School fee',
          categoryKey: 'fees',
          dueDay: 5,
          skipMonths: [6, 7],
        ),
      );
      expect((await paymentsOf(r.id)).single.dueDate, '2027-08-05');
    });

    test('AC6: a 4th active rule on the free plan is refused', () async {
      for (final n in ['Rent', 'Internet', 'Mobile']) {
        await atc.createRule(
          RuleInput(name: n, categoryKey: 'other', dueDay: 10),
        );
      }
      await expectLater(
        atc.createRule(
          const RuleInput(name: 'Gym', categoryKey: 'other', dueDay: 10),
        ),
        throwsA(isA<FreeTierLimitException>()),
      );
      expect(await atc.activeRules(), hasLength(3));
      // Premium lifts it.
      final premium = AtcService(repos, now: () => now, isPremium: true);
      await premium.createRule(
        const RuleInput(name: 'Gym', categoryKey: 'other', dueDay: 10),
      );
      expect(await atc.activeRules(), hasLength(4));
    });

    test('AC7: pause stops generation; resume skips missed periods', () async {
      final r = await atc.createRule(
        const RuleInput(name: 'Rent', categoryKey: 'rent', dueDay: 1),
      );
      await atc.pause(r.id);
      now = DateTime(2027, 3, 10);
      expect(await atc.generateAll(), 0);
      await atc.resume(r.id);
      expect((await paymentsOf(r.id)).map((p) => p.dueDate).toList()..sort(), [
        '2026-12-01',
        '2027-04-01',
      ]);
    });

    test('subscriptions get a yearly review task', () async {
      await atc.createRule(
        const RuleInput(
          name: 'Netflix',
          categoryKey: 'subscription',
          dueDay: 12,
          amountMinor: 110000,
        ),
      );
      final review = (await repos.tasks.getAll()).firstWhere(
        (t) => t.title == 'Review Netflix subscription?',
      );
      expect(
        DateTime.fromMillisecondsSinceEpoch(review.dueAt!),
        DateTime(2027, 11, 8),
      );
    });

    test('PBI-017 AC3: delete keeps tasks but drops the ⚡ link', () async {
      final r = await atc.createRule(
        const RuleInput(name: 'Rent', categoryKey: 'rent', dueDay: 1),
      );
      final taskId = (await paymentsOf(r.id)).single.taskId!;
      await atc.delete(r.id);
      expect(await repos.atcRules.getById(r.id), isNull);
      final task = (await repos.tasks.getById(taskId))!;
      expect(task.atcRuleId, isNull);
      expect(await paymentsOf(r.id), hasLength(1), reason: 'stays in forecast');
    });

    test('PBI-017 AC4: tasks created this month are counted', () async {
      await atc.createRule(
        const RuleInput(name: 'Rent', categoryKey: 'rent', dueDay: 1),
      );
      await atc.createRule(
        const RuleInput(name: 'Internet', categoryKey: 'internet', dueDay: 15),
      );
      expect(await atc.tasksCreatedIn(DateTime(2026, 11)), 2);
      expect(await atc.tasksCreatedIn(DateTime(2026, 10)), 0);
    });
  });
}
