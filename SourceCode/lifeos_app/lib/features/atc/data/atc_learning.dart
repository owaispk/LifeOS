import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/ids.dart';
import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/domain/money_rules.dart' show isoDate, parseIsoDate;
import '../../vault/domain/expiry_ladder.dart' show billLadder, futureAlerts;
import '../domain/atc_schedule.dart';
import '../domain/bill_patterns.dart';

/// Tag added to a document whose amount is a spike (PBI-014 AC6).
const spikeTag = '⚠ Unusually high bill';

/// A scanned fee voucher whose amount differs from its rule (PBI-015 AC2).
class FeeChange {
  const FeeChange({
    required this.rule,
    required this.oldMinor,
    required this.newMinor,
  });

  final AtcRule rule;
  final int oldMinor;
  final int newMinor;

  bool get isIncrease => newMinor > oldMinor;

  String get message {
    final from = Money.formatPlain(oldMinor);
    final to = Money.formatPlain(newMinor);
    return isIncrease
        ? l10nNow.atcFeeIncreasedMsg(from, to)
        : l10nNow.atcFeeDecreasedMsg(from, to);
  }
}

/// What saving one document taught the Auto Task Creator.
class LearningOutcome {
  const LearningOutcome({
    this.spike = false,
    this.upgradedTaskId,
    this.proposed,
    this.feeChange,
  });

  static const none = LearningOutcome();

  /// The bill is more than 2× the usual amount (AC6).
  final bool spike;

  /// The predicted task that this bill upgraded in place (AC5), or the
  /// bill task created for the rule when no prediction was open.
  final String? upgradedTaskId;

  /// A new proposed rule waiting in the M1 queue.
  final AtcRule? proposed;

  /// A fee voucher's amount differs from its rule; ask the user.
  final FeeChange? feeChange;
}

/// Learns from scanned bills and fee vouchers (PBI-014, PBI-015). Runs
/// right after a document is saved on the confirm step.
class AtcLearningService {
  AtcLearningService(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  AppDatabase get _db => _repos.db;

  Future<LearningOutcome> onDocumentSaved(Document doc) async {
    return switch (doc.docType) {
      'bill' => _learnBill(doc),
      'fee_voucher' => _learnFee(doc),
      _ => LearningOutcome.none,
    };
  }

  // ───────────────────────────── Bills ─────────────────────────────

  BillObservation _observe(Document d) {
    final scanned = DateTime.fromMillisecondsSinceEpoch(
      IdGenerator.timestampOf(d.id),
    );
    final period = d.periodMonth == null ? null : parseIsoDate(d.periodMonth!);
    return BillObservation(
      documentId: d.id,
      issuer: d.issuer!,
      ref: d.refNumber ?? '',
      month: period ?? DateTime(scanned.year, scanned.month),
      arrivalDay: scanned.day,
      amountMinor: d.amountMinor,
    );
  }

  Future<LearningOutcome> _learnBill(Document doc) {
    final issuer = doc.issuer;
    if (issuer == null) return Future.value(LearningOutcome.none);
    final ref = doc.refNumber ?? '';
    return _db.transaction(() async {
      final bills =
          (await _repos.documents.getWhere(
              (d) => d.docType.equals('bill') & d.issuer.equals(issuer),
            )).where((d) => (d.refNumber ?? '') == ref).toList()
            ..sort((a, b) => a.id.compareTo(b.id)); // oldest first
      final previous = [
        for (final d in bills)
          if (d.id != doc.id && d.amountMinor != null) d.amountMinor!,
      ];

      // Spike (AC6): tag the document; the task gets ⚠ below.
      final spike =
          doc.amountMinor != null && isSpike(doc.amountMinor!, previous);
      if (spike) {
        final tags = (jsonDecode(doc.tags) as List).cast<String>();
        if (!tags.contains(spikeTag)) {
          await _repos.documents.update(
            doc.id,
            DocumentsCompanion(tags: Value(jsonEncode([...tags, spikeTag]))),
          );
        }
      }

      final rule = (await _repos.atcRules.getWhere(
        (r) => r.kind.equals('bill_pattern') & r.issuer.equals(issuer),
      )).where((r) => (r.refNumber ?? '') == ref).firstOrNull;

      final candidate = detectPattern([for (final d in bills) _observe(d)]);

      if (rule == null) {
        if (candidate == null || !candidate.proposable) {
          return LearningOutcome(spike: spike);
        }
        final proposed = await _proposeBillRule(candidate);
        return LearningOutcome(spike: spike, proposed: proposed);
      }

      // Keep the learned window and amount range fresh.
      if (candidate != null) await _refreshStats(rule, candidate);
      if (rule.status != 'active') return LearningOutcome(spike: spike);

      final taskId = await _upgrade(
        (await _repos.atcRules.getById(rule.id))!,
        doc,
        spike: spike,
        usual: previous.isEmpty ? null : usualAmount(previous),
      );
      return LearningOutcome(spike: spike, upgradedTaskId: taskId);
    });
  }

  Future<AtcRule> _proposeBillRule(PatternCandidate c) async {
    final categories = await _repos.categories.getAll();
    final key = billCategoryKey(c.issuer);
    final label = billLabel(c.issuer);
    return _repos.atcRules.insert(
      AtcRulesCompanion.insert(
        kind: 'bill_pattern',
        name: '${capitalized(label)} bill (${c.issuer})',
        issuer: Value(c.issuer),
        refNumber: Value(c.ref.isEmpty ? null : c.ref),
        dueDay: Value(c.predictedDay),
        expectedWindow: Value(
          jsonEncode({'from': c.windowFrom, 'to': c.windowTo}),
        ),
        amountAvgMinor: Value(c.amountAvgMinor),
        confidence: Value(c.confidence),
        remindDaysBefore: const Value(0),
        stats: Value(_statsJson(label, c)),
        categoryId: Value(
          categories.where((x) => x.systemKey == key).firstOrNull?.id,
        ),
      ),
    );
  }

  String _statsJson(String label, PatternCandidate c) => jsonEncode({
    'label': label,
    'min': ?c.amountMinMinor,
    'max': ?c.amountMaxMinor,
  });

  Future<void> _refreshStats(AtcRule rule, PatternCandidate c) =>
      _repos.atcRules.update(
        rule.id,
        AtcRulesCompanion(
          expectedWindow: Value(
            jsonEncode({'from': c.windowFrom, 'to': c.windowTo}),
          ),
          amountAvgMinor: Value(c.amountAvgMinor ?? rule.amountAvgMinor),
          confidence: Value(c.confidence),
          stats: Value(
            _statsJson(billStatsOf(rule).label ?? billLabel(c.issuer), c),
          ),
        ),
      );

  /// AC5: the real bill upgrades the rule's open predicted task in place —
  /// same task id — with the exact amount and due date, and the reminder
  /// ladder moves to the due date. Without an open prediction, a bill
  /// task is created for the rule.
  Future<String> _upgrade(
    AtcRule rule,
    Document doc, {
    required bool spike,
    required int? usual,
  }) async {
    final now = _now();
    final label = billStatsOf(rule).label ?? billLabel(rule.issuer ?? '');
    final amount = doc.amountMinor;
    final title = [
      '${capitalized(label)} bill',
      if (amount != null) ' — ${Money.format(amount)}',
      if (spike) ' ⚠',
    ].join();
    final notes = spike && usual != null && amount != null
        ? 'Unusually high bill — ${Money.format(amount)} vs usual '
              '${Money.format(usual)}'
        : null;

    final open = await _repos.payments.getWhere(
      (p) =>
          p.atcRuleId.equals(rule.id) & p.status.isNotIn(['paid', 'skipped']),
    );
    open.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    Payment? payment;
    Task? task;
    for (final p in open) {
      final t = p.taskId == null ? null : await _repos.tasks.getById(p.taskId!);
      if (t != null && t.status == 'open' && t.sourceDocumentId == null) {
        payment = p;
        task = t;
        break;
      }
    }

    final due = doc.dueDate == null
        ? (task?.dueAt == null
              ? DateTime(now.year, now.month, now.day)
              : DateTime.fromMillisecondsSinceEpoch(task!.dueAt!))
        : parseIsoDate(doc.dueDate!);
    final dueDay = DateTime(due.year, due.month, due.day);

    if (task == null || payment == null) {
      task = await _repos.tasks.insert(
        TasksCompanion.insert(
          title: title,
          notes: Value(notes),
          domain: const Value('money'),
          dueAt: Value(dueDay.millisecondsSinceEpoch),
          personId: Value(rule.personId),
          atcRuleId: Value(rule.id),
          sourceDocumentId: Value(doc.id),
          durationMin: const Value(15),
          priority: Value(spike ? 2 : 1),
        ),
      );
      payment = await _repos.payments.insert(
        PaymentsCompanion.insert(
          title: rule.name,
          dueDate: isoDate(dueDay),
          periodMonth: isoDate(DateTime(dueDay.year, dueDay.month)),
          taskId: Value(task.id),
          atcRuleId: Value(rule.id),
          categoryId: Value(rule.categoryId),
          amountMinor: Value(amount),
        ),
      );
      final last = rule.lastGeneratedPeriod;
      if (last == null || isoDate(dueDay).compareTo(last) > 0) {
        await _repos.atcRules.update(
          rule.id,
          AtcRulesCompanion(lastGeneratedPeriod: Value(isoDate(dueDay))),
        );
      }
    } else {
      task = await _repos.tasks.update(
        task.id,
        TasksCompanion(
          title: Value(title),
          notes: Value(notes ?? task.notes),
          dueAt: Value(dueDay.millisecondsSinceEpoch),
          sourceDocumentId: Value(doc.id),
          priority: Value(spike ? 2 : task.priority),
        ),
      );
      await _repos.payments.update(
        payment.id,
        PaymentsCompanion(
          amountMinor: Value(amount ?? payment.amountMinor),
          dueDate: Value(isoDate(dueDay)),
        ),
      );
      for (final r in await _repos.taskReminders.getWhere(
        (r) => r.taskId.equals(task!.id),
      )) {
        await _repos.taskReminders.softDelete(r.id);
      }
    }

    // Reminder ladder on the real due date: 3 days before, the day, +1.
    for (final at in futureAlerts(dueDay, billLadder, now)) {
      await _repos.taskReminders.insert(
        TaskRemindersCompanion.insert(
          taskId: task.id,
          fireAt: at.millisecondsSinceEpoch,
        ),
      );
    }
    return task.id;
  }

  // ───────────────────────────── Fees ─────────────────────────────

  Future<LearningOutcome> _learnFee(Document doc) async {
    final fields = await _repos.extractedFields.getWhere(
      (f) => f.documentId.equals(doc.id),
    );
    String? field(String k) =>
        fields.where((f) => f.field == k).firstOrNull?.value;
    final institution = doc.issuer ?? field('institution');
    final student = field('student_name');

    final persons = await _repos.persons.getAll();
    final person = doc.personId != null
        ? persons.where((p) => p.id == doc.personId).firstOrNull
        : student == null
        ? null
        : persons
              .where(
                (p) =>
                    p.name.toLowerCase().trim() == student.toLowerCase().trim(),
              )
              .firstOrNull;

    bool sameInstitution(AtcRule r) =>
        r.issuer == null ||
        institution == null ||
        r.issuer!.toLowerCase() == institution.toLowerCase();

    final rule = (await _repos.atcRules.getWhere((r) => r.kind.equals('fee')))
        .where((r) => r.personId == person?.id && sameInstitution(r))
        .firstOrNull;
    final amount = doc.amountMinor;

    if (rule != null) {
      if (rule.issuer == null && institution != null) {
        await _repos.atcRules.update(
          rule.id,
          AtcRulesCompanion(issuer: Value(institution)),
        );
      }
      if (rule.status == 'dismissed' || amount == null) {
        return LearningOutcome.none;
      }
      final old = rule.amountMinor;
      if (old != null && old != amount) {
        return LearningOutcome(
          feeChange: FeeChange(rule: rule, oldMinor: old, newMinor: amount),
        );
      }
      return LearningOutcome.none;
    }

    // First voucher for this child + school: propose a fee rule.
    if (amount == null || doc.dueDate == null) return LearningOutcome.none;
    final categories = await _repos.categories.getAll();
    final proposed = await _repos.atcRules.insert(
      AtcRulesCompanion.insert(
        kind: 'fee',
        name: 'School fee',
        issuer: Value(institution),
        personId: Value(person?.id),
        amountMinor: Value(amount),
        dueDay: Value(parseIsoDate(doc.dueDate!).day),
        remindDaysBefore: const Value(5),
        categoryId: Value(
          categories.where((c) => c.systemKey == 'fees').firstOrNull?.id,
        ),
      ),
    );
    return LearningOutcome(proposed: proposed);
  }

  /// "Update future tasks?" → yes (PBI-015 AC2): the rule's amount and
  /// every not-yet-paid payment (and its task title) change. Paid history
  /// stays as it was.
  Future<void> applyFeeChange(FeeChange change) {
    return _db.transaction(() async {
      final rule = await _repos.atcRules.update(
        change.rule.id,
        AtcRulesCompanion(amountMinor: Value(change.newMinor)),
      );
      final person = rule.personId == null
          ? null
          : await _repos.persons.getById(rule.personId!);
      for (final p in await _repos.payments.getWhere(
        (p) =>
            p.atcRuleId.equals(rule.id) & p.status.isNotIn(['paid', 'skipped']),
      )) {
        await _repos.payments.update(
          p.id,
          PaymentsCompanion(amountMinor: Value(change.newMinor)),
        );
        if (p.taskId == null) continue;
        final task = await _repos.tasks.getById(p.taskId!);
        if (task == null || task.status != 'open') continue;
        await _repos.tasks.update(
          task.id,
          TasksCompanion(
            title: Value(
              occurrenceTitle(
                rule,
                personName: person?.name,
                due: parseIsoDate(p.dueDate),
              ),
            ),
          ),
        );
      }
    });
  }
}
