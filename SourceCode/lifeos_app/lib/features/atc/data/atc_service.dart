import 'package:drift/drift.dart';

import '../../../core/ids.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/domain/money_rules.dart' show isoDate;
import '../domain/atc_schedule.dart';

/// Thrown when a 4th active rule is added on the free plan (AC6).
class FreeTierLimitException implements Exception {
  const FreeTierLimitException();

  @override
  String toString() =>
      'Free plan includes $freeTierRuleLimit auto-rules — Premium removes '
      'the limit';
}

/// What the "What do you pay regularly?" form produces.
class RuleInput {
  const RuleInput({
    required this.name,
    required this.categoryKey,
    required this.dueDay,
    this.amountMinor,
    this.cycle = 'monthly',
    this.skipMonths = const [],
    this.installmentTotal,
    this.remindDaysBefore = 5,
    this.personId,
    this.kind = 'fixed',
  });

  final String name;

  /// System category key: rent | fees | utilities | internet | mobile |
  /// installment | subscription | other.
  final String categoryKey;
  final int dueDay;
  final int? amountMinor;
  final String cycle;
  final List<int> skipMonths;
  final int? installmentTotal;
  final int remindDaysBefore;
  final String? personId;
  final String kind;
}

/// Auto Task Creator use-cases (PBI-013, PBI-017).
class AtcService {
  AtcService(this._repos, {DateTime Function()? now, this.isPremium = false})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;
  final bool isPremium;

  AppDatabase get _db => _repos.db;

  Future<List<AtcRule>> activeRules() =>
      _repos.atcRules.getWhere((r) => r.status.equals('active'));

  /// Creates a rule and immediately generates its next occurrence (AC1).
  Future<AtcRule> createRule(RuleInput input) {
    return _db.transaction(() async {
      if (!isPremium && (await activeRules()).length >= freeTierRuleLimit) {
        throw const FreeTierLimitException();
      }
      final categories = await _repos.categories.getAll();
      final category = categories
          .where((c) => c.systemKey == input.categoryKey)
          .firstOrNull;
      final rule = await _repos.atcRules.insert(
        AtcRulesCompanion.insert(
          kind: input.kind,
          name: input.name.trim(),
          amountMinor: Value(input.amountMinor),
          dueDay: Value(input.dueDay.clamp(1, 31)),
          cycle: Value(input.cycle),
          skipMonths: Value(
            '[${(input.skipMonths.toList()..sort()).join(',')}]',
          ),
          installmentTotal: Value(input.installmentTotal),
          installmentDone: Value(input.installmentTotal == null ? null : 0),
          remindDaysBefore: Value(input.remindDaysBefore),
          personId: Value(input.personId),
          status: const Value('active'),
          categoryId: Value(category?.id),
        ),
      );
      if (input.categoryKey == 'subscription') {
        final n = _now();
        await _repos.tasks.insert(
          TasksCompanion.insert(
            title: 'Review ${rule.name} subscription?',
            domain: const Value('money'),
            dueAt: Value(
              DateTime(n.year + 1, n.month, n.day).millisecondsSinceEpoch,
            ),
          ),
        );
      }
      await generateFor(rule);
      return (await _repos.atcRules.getById(rule.id))!;
    });
  }

  /// Runs the generator for every active rule (app start / resume).
  /// Returns how many occurrences were created.
  Future<int> generateAll() async {
    var n = 0;
    for (final r in await activeRules()) {
      if (await generateFor(r) != null) n++;
    }
    return n;
  }

  /// Creates the next task + payment (+ reminder) for [rule] if one is due
  /// to exist; idempotent per period (AC2).
  Future<Payment?> generateFor(AtcRule rule) {
    return _db.transaction(() async {
      final fresh = await _repos.atcRules.getById(rule.id);
      if (fresh == null) return null;
      final payments = await _repos.payments.getWhere(
        (p) => p.atcRuleId.equals(fresh.id),
      );
      final plan = planNext(
        fresh,
        today: _now(),
        generatedCount: payments.length,
      );
      if (plan == null) return null;

      final task = await _repos.tasks.insert(
        TasksCompanion.insert(
          title: plan.title,
          domain: const Value('money'),
          dueAt: Value(plan.due.millisecondsSinceEpoch),
          personId: Value(fresh.personId),
          atcRuleId: Value(fresh.id),
          durationMin: const Value(15),
        ),
      );
      final payment = await _repos.payments.insert(
        PaymentsCompanion.insert(
          title: fresh.name,
          dueDate: isoDate(plan.due),
          periodMonth: isoDate(DateTime(plan.due.year, plan.due.month)),
          taskId: Value(task.id),
          atcRuleId: Value(fresh.id),
          categoryId: Value(fresh.categoryId),
          amountMinor: Value(fresh.amountMinor ?? fresh.amountAvgMinor),
        ),
      );
      final remindAt = reminderFor(plan.due, fresh.remindDaysBefore);
      if (remindAt.isAfter(_now())) {
        await _repos.taskReminders.insert(
          TaskRemindersCompanion.insert(
            taskId: task.id,
            fireAt: remindAt.millisecondsSinceEpoch,
          ),
        );
      }
      await _repos.atcRules.update(
        fresh.id,
        AtcRulesCompanion(
          lastGeneratedPeriod: Value(periodKey(plan.due)),
          status: Value(fresh.cycle == 'once' ? 'ended' : fresh.status),
        ),
      );
      return payment;
    });
  }

  Future<AtcRule> pause(String id) => _repos.atcRules.update(
    id,
    const AtcRulesCompanion(status: Value('paused')),
  );

  /// Resumes without back-filling (AC7): generation picks the next due
  /// date on or after today.
  Future<AtcRule> resume(String id) async {
    if (!isPremium && (await activeRules()).length >= freeTierRuleLimit) {
      throw const FreeTierLimitException();
    }
    final r = await _repos.atcRules.update(
      id,
      const AtcRulesCompanion(status: Value('active')),
    );
    await generateFor(r);
    return (await _repos.atcRules.getById(id))!;
  }

  Future<AtcRule> edit(
    String id, {
    required String name,
    required int? amountMinor,
    required int dueDay,
    required int remindDaysBefore,
    required List<int> skipMonths,
  }) => _repos.atcRules.update(
    id,
    AtcRulesCompanion(
      name: Value(name.trim()),
      amountMinor: Value(amountMinor),
      dueDay: Value(dueDay.clamp(1, 31)),
      remindDaysBefore: Value(remindDaysBefore),
      skipMonths: Value('[${(skipMonths.toList()..sort()).join(',')}]'),
    ),
  );

  /// Soft-deletes a rule (PBI-017 AC3): its tasks stay but lose the ⚡
  /// link; unpaid payments stay in the forecast.
  Future<void> delete(String id) {
    return _db.transaction(() async {
      for (final t in await _repos.tasks.getWhere(
        (t) => t.atcRuleId.equals(id),
      )) {
        await _repos.tasks.update(
          t.id,
          const TasksCompanion(atcRuleId: Value(null)),
        );
      }
      await _repos.atcRules.softDelete(id);
    });
  }

  /// Live ATC tasks created in [month]'s calendar month (PBI-017 AC4).
  Future<int> tasksCreatedIn(DateTime month) async {
    final tasks = await _repos.tasks.getWhere((t) => t.atcRuleId.isNotNull());
    return tasks.where((t) {
      final created = DateTime.fromMillisecondsSinceEpoch(
        IdGenerator.timestampOf(t.id),
      );
      return created.year == month.year && created.month == month.month;
    }).length;
  }
}
