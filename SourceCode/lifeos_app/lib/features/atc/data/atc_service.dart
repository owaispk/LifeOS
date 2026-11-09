import 'package:drift/drift.dart';

import '../../../core/ids.dart';
import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/domain/money_rules.dart' show isoDate;
import '../domain/atc_schedule.dart';

/// Thrown when a 4th active rule is added on the free plan (AC6).
class FreeTierLimitException implements Exception {
  const FreeTierLimitException();

  @override
  String toString() => l10nNow.atcFreeLimit('$freeTierRuleLimit');
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
    this.scheduleDates = const [],
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

  /// Explicit due dates for date-based cycles such as semesters (PBI-015).
  final List<DateTime> scheduleDates;
}

/// Key in `app_meta` for the day the last M1 proposal was shown.
const proposalShownKey = 'atc_proposal_shown_day';

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
      final dates = input.scheduleDates.toList()..sort();
      // School fees from the form follow the fee flow (PBI-015).
      final kind = input.kind == 'fixed' && input.categoryKey == 'fees'
          ? 'fee'
          : input.kind;
      final rule = await _repos.atcRules.insert(
        AtcRulesCompanion.insert(
          kind: kind,
          name: input.name.trim(),
          amountMinor: Value(input.amountMinor),
          dueDay: Value(
            (dates.isEmpty ? input.dueDay : dates.first.day).clamp(1, 31),
          ),
          scheduleDates: Value(
            dates.isEmpty
                ? null
                : '[${dates.map((d) => '"${isoDate(d)}"').join(',')}]',
          ),
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
        // Stored task title (data, not UI) — stays English.
        final reviewTitle = 'Review ${rule.name} subscription?';
        await _repos.tasks.insert(
          TasksCompanion.insert(
            title: reviewTitle,
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
      final person = fresh.personId == null
          ? null
          : await _repos.persons.getById(fresh.personId!);
      final title = occurrenceTitle(
        fresh,
        installment: plan.installmentNumber,
        personName: person?.name,
        due: plan.due,
      );

      final task = await _repos.tasks.insert(
        TasksCompanion.insert(
          title: title,
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

  // ───────────────────── Proposals (M1, PBI-014/015) ─────────────────────

  /// The oldest proposed rule, unless one was already shown today (max one
  /// proposal per day; the rest queue). Marks the day as used.
  Future<AtcRule?> takeProposalForToday() async {
    final today = isoDate(_now());
    final meta = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(proposalShownKey))).getSingleOrNull();
    if (meta?.value == today) return null;
    final proposed = await _repos.atcRules.getWhere(
      (r) => r.status.equals('proposed'),
    );
    if (proposed.isEmpty) return null;
    proposed.sort((a, b) => a.id.compareTo(b.id));
    await _db
        .into(_db.appMeta)
        .insertOnConflictUpdate(
          AppMetaCompanion.insert(key: proposalShownKey, value: today),
        );
    return proposed.first;
  }

  /// "Yes, remind me": the rule goes live and gets its first task.
  Future<AtcRule> acceptProposal(String id) async {
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

  /// "No thanks": never proposed again for this issuer + ref (AC3).
  Future<AtcRule> dismissProposal(String id) => _repos.atcRules.update(
    id,
    const AtcRulesCompanion(status: Value('dismissed')),
  );

  /// The M1 question for a proposed rule.
  Future<String> proposalText(AtcRule r) async {
    if (r.kind == 'fee') {
      final person = r.personId == null
          ? null
          : await _repos.persons.getById(r.personId!);
      final l = l10nNow;
      final who = person == null ? '' : l.atcProposalFor(person.name);
      final amount = r.amountMinor == null
          ? ''
          : ' — ${Money.format(r.amountMinor!)}';
      final day = r.dueDay == null ? '' : l.atcProposalDue(ordinal(r.dueDay!));
      return l.atcProposalFee(who, amount, day);
    }
    final l = l10nNow;
    final label = billStatsOf(r).label ?? l.atcUtility;
    final window = windowOf(r);
    final when = window == null
        ? ''
        : l.atcProposalWindow(ordinal(window.from), ordinal(window.to));
    return l.atcProposalBill(label, when);
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
