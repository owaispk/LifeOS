// PBI-014 bill pattern learning and PBI-015 fees: pure detection (AC7) and
// the learning service on a real database.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/atc/data/atc_learning.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:lifeos_app/features/atc/domain/atc_schedule.dart';
import 'package:lifeos_app/features/atc/domain/bill_patterns.dart';
import 'package:lifeos_app/features/money/data/payment_service.dart';
import 'package:lifeos_app/features/money/domain/money_rules.dart' show isoDate;

import '../../data/db_test_utils.dart';

BillObservation bill(
  int month,
  int day, {
  int? amount = 500000,
  String ref = 'M1',
  String issuer = 'K-Electric',
  int year = 2026,
}) => BillObservation(
  documentId: '$issuer$ref$year$month',
  issuer: issuer,
  ref: ref,
  month: DateTime(year, month),
  arrivalDay: day,
  amountMinor: amount,
);

void main() {
  group('detection (pure, AC7)', () {
    test('AC1: two consecutive months on the 11th and 13th → proposal', () {
      final c = detectPattern([bill(9, 11), bill(10, 13)])!;
      expect(c.cycles, 2);
      expect((c.windowFrom, c.windowTo, c.predictedDay), (11, 13, 12));
      expect(c.confidence, closeTo(0.72, 1e-9));
      expect(c.proposable, isTrue);
    });

    test('AC1: a single bill is not a pattern', () {
      expect(detectPattern([bill(10, 12)]), isNull);
    });

    test('AC2: arrival days 2 and 20 are irregular → nothing', () {
      expect(detectPattern([bill(9, 2), bill(10, 20)]), isNull);
    });

    test('months must be consecutive: a gap restarts the run', () {
      expect(detectPattern([bill(6, 11), bill(9, 12)]), isNull);
      final c = detectPattern([bill(3, 5), bill(8, 11), bill(9, 12)])!;
      expect(c.cycles, 2, reason: 'only Aug–Sep count');
    });

    test('runs across a year boundary are consecutive', () {
      final c = detectPattern([
        bill(12, 10, year: 2025),
        bill(1, 11),
        bill(2, 12),
      ])!;
      expect(c.cycles, 3);
    });

    test('confidence grows with cycles and falls with spread', () {
      expect(patternConfidence(1, 0), 0);
      expect(patternConfidence(2, 0), 0.75);
      expect(patternConfidence(3, 0), 0.85);
      expect(patternConfidence(6, 0), 0.95);
      expect(patternConfidence(2, 2), closeTo(0.69, 1e-9));
      expect(patternConfidence(3, 4), closeTo(0.73, 1e-9));
    });

    test('2 bills 4 days apart wait for a 3rd before proposing', () {
      final two = detectPattern([bill(9, 10), bill(10, 14)])!;
      expect(two.proposable, isFalse); // σ 2 → 0.69
      final three = detectPattern([bill(8, 12), bill(9, 10), bill(10, 14)])!;
      expect(three.proposable, isTrue);
    });

    test('AC4: two meters from one issuer are two patterns', () {
      final found = detectPatterns([
        bill(9, 11, ref: 'A'),
        bill(10, 12, ref: 'A'),
        bill(9, 20, ref: 'B'),
        bill(10, 21, ref: 'B'),
      ]);
      expect(found.map((c) => (c.ref, c.predictedDay)).toSet(), {
        ('A', 12),
        ('B', 21),
      });
    });

    test('a rescan of the same month keeps the newest', () {
      final run = latestRun([bill(9, 11), bill(10, 3), bill(10, 13)]);
      expect(run.map((b) => b.arrivalDay), [11, 13]);
    });

    test('amount average and the Rs 500 range', () {
      final c = detectPattern([
        bill(9, 11, amount: 412000),
        bill(10, 12, amount: 586000),
      ])!;
      expect(c.amountAvgMinor, 499000);
      expect((c.amountMinMinor, c.amountMaxMinor), (400000, 600000));
    });

    test('AC6: spike = more than 2× the average of earlier bills', () {
      expect(isSpike(1000000, [400000, 500000]), isTrue);
      expect(isSpike(900000, [400000, 500000]), isFalse);
      expect(isSpike(900000, const []), isFalse, reason: 'needs history');
      // Only the last 6 bills count.
      expect(
        isSpike(500000, [
          10,
          10,
          10,
          200000,
          200000,
          200000,
          200000,
          200000,
          200000,
        ]),
        isTrue,
      );
      expect(usualAmount([400000, 500000]), 450000);
    });

    test('labels and categories by issuer', () {
      expect(billLabel('K-Electric'), 'electricity');
      expect(billLabel('SSGC'), 'gas');
      expect(billLabel('PTCL'), 'internet');
      expect(billCategoryKey('PTCL'), 'internet');
      expect(billCategoryKey('Jazz'), 'mobile');
      expect(billCategoryKey('SNGPL'), 'utilities');
    });

    test('a bill is late 3 days after its window', () {
      final predicted = DateTime(2026, 11, 12);
      bool late(DateTime d) =>
          isBillLate(predictedArrival: predicted, windowTo: 14, today: d);
      expect(late(DateTime(2026, 11, 17)), isFalse);
      expect(late(DateTime(2026, 11, 18)), isTrue);
    });
  });

  group('service (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    late AtcService atc;
    late AtcLearningService learn;
    var now = DateTime(2026, 9, 11, 10);

    setUp(() async {
      db = memoryDb();
      now = DateTime(2026, 9, 11, 10);
      await openLocalData(db);
      repos = await Repositories.open(
        db,
        clock: () => now.millisecondsSinceEpoch,
      );
      atc = AtcService(repos, now: () => now);
      learn = AtcLearningService(repos, now: () => now);
    });
    tearDown(() => db.close());

    /// Scans a bill on [at] (its arrival day) and runs the learner.
    Future<(Document, LearningOutcome)> scanBill(
      DateTime at, {
      int? amount = 500000,
      String ref = 'M1',
      String issuer = 'K-Electric',
      String? due,
    }) async {
      now = at;
      final doc = await repos.documents.insert(
        DocumentsCompanion.insert(
          title: '$issuer bill',
          docType: const Value('bill'),
          issuer: Value(issuer),
          refNumber: Value(ref),
          periodMonth: Value(isoDate(DateTime(at.year, at.month))),
          amountMinor: Value(amount),
          dueDate: Value(due),
        ),
      );
      final fresh = (await repos.documents.getById(doc.id))!;
      return (fresh, await learn.onDocumentSaved(fresh));
    }

    Future<List<AtcRule>> billRules() =>
        repos.atcRules.getWhere((r) => r.kind.equals('bill_pattern'));

    test(
      'AC1: the 2nd regular bill proposes a rule; the 1st does not',
      () async {
        final (_, first) = await scanBill(DateTime(2026, 9, 11, 10));
        expect(first.proposed, isNull);
        final (_, second) = await scanBill(
          DateTime(2026, 10, 13, 10),
          amount: 586000,
        );
        final r = second.proposed!;
        expect(
          (r.status, r.issuer, r.refNumber, r.dueDay),
          ('proposed', 'K-Electric', 'M1', 12),
        );
        expect(jsonDecode(r.expectedWindow!), {'from': 11, 'to': 13});
        expect(r.name, 'Electricity bill (K-Electric)');
        expect(
          await atc.proposalText(r),
          'Your electricity bill usually arrives the 11th–13th. '
          'Create a monthly reminder?',
        );
        expect(r.remindDaysBefore, 0);
      },
    );

    test('AC2: irregular arrival days propose nothing', () async {
      await scanBill(DateTime(2026, 9, 2, 10));
      final (_, o) = await scanBill(DateTime(2026, 10, 20, 10));
      expect(o.proposed, isNull);
      expect(await billRules(), isEmpty);
    });

    test(
      'AC3: declining dismisses it for good for that issuer + ref',
      () async {
        await scanBill(DateTime(2026, 9, 11, 10));
        final (_, o) = await scanBill(DateTime(2026, 10, 12, 10));
        await atc.dismissProposal(o.proposed!.id);
        final (_, again) = await scanBill(DateTime(2026, 11, 12, 10));
        expect(again.proposed, isNull);
        final rules = await billRules();
        expect(rules.single.status, 'dismissed');
        expect(await repos.tasks.getAll(), isEmpty, reason: 'never silent');
      },
    );

    test('AC4: two meters are learned as two rules', () async {
      await scanBill(DateTime(2026, 9, 11, 10), ref: 'A');
      await scanBill(DateTime(2026, 9, 20, 10), ref: 'B');
      await scanBill(DateTime(2026, 10, 12, 10), ref: 'A');
      await scanBill(DateTime(2026, 10, 21, 10), ref: 'B');
      final rules = await billRules();
      expect(rules.map((r) => (r.refNumber, r.dueDay)).toSet(), {
        ('A', 12),
        ('B', 21),
      });
    });

    test(
      'accepting creates the predicted task "Expect electricity bill"',
      () async {
        await scanBill(DateTime(2026, 9, 11, 10), amount: 412000);
        final (_, o) = await scanBill(
          DateTime(2026, 10, 13, 10),
          amount: 586000,
        );
        now = DateTime(2026, 10, 20, 10);
        await atc.acceptProposal(o.proposed!.id);
        final task = (await repos.tasks.getWhere(
          (t) => t.atcRuleId.equals(o.proposed!.id),
        )).single;
        expect(task.title, 'Expect electricity bill (~Rs 4,000–6,000)');
        expect(
          DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
          DateTime(2026, 11, 12),
        );
        expect(task.sourceDocumentId, isNull);
      },
    );

    test('AC5: the real bill upgrades the predicted task in place', () async {
      await scanBill(DateTime(2026, 9, 11, 10));
      final (_, o) = await scanBill(DateTime(2026, 10, 13, 10));
      now = DateTime(2026, 10, 20, 10);
      await atc.acceptProposal(o.proposed!.id);
      final predicted = (await repos.tasks.getWhere(
        (t) => t.atcRuleId.equals(o.proposed!.id),
      )).single;

      final (doc, up) = await scanBill(
        DateTime(2026, 11, 12, 10),
        amount: 485000,
        due: '2026-11-24',
      );
      expect(up.upgradedTaskId, predicted.id, reason: 'same task id');
      final task = (await repos.tasks.getById(predicted.id))!;
      expect(task.title, 'Electricity bill — Rs 4,850');
      expect(task.sourceDocumentId, doc.id);
      expect(
        DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
        DateTime(2026, 11, 24),
      );
      final pay = (await repos.payments.getWhere(
        (p) => p.taskId.equals(task.id),
      )).single;
      expect((pay.amountMinor, pay.dueDate), (485000, '2026-11-24'));
      final reminders = await repos.taskReminders.getWhere(
        (r) => r.taskId.equals(task.id),
      );
      expect(
        [
          for (final r in reminders)
            DateTime.fromMillisecondsSinceEpoch(r.fireAt),
        ]..sort(),
        [
          DateTime(2026, 11, 21, 9),
          DateTime(2026, 11, 24, 9),
          DateTime(2026, 11, 25, 9),
        ],
      );
      expect(await repos.tasks.getAll(), hasLength(1), reason: 'no duplicate');
    });

    test('AC6: a spike tags the document and flags the task ⚠', () async {
      await scanBill(DateTime(2026, 9, 11, 10), amount: 400000);
      final (_, o) = await scanBill(DateTime(2026, 10, 12, 10), amount: 500000);
      now = DateTime(2026, 10, 20, 10);
      await atc.acceptProposal(o.proposed!.id);
      final (doc, up) = await scanBill(
        DateTime(2026, 11, 12, 10),
        amount: 1200000,
        due: '2026-11-24',
      );
      expect(up.spike, isTrue);
      final stored = (await repos.documents.getById(doc.id))!;
      expect(jsonDecode(stored.tags), contains(spikeTag));
      final task = (await repos.tasks.getById(up.upgradedTaskId!))!;
      expect(task.title, 'Electricity bill — Rs 12,000 ⚠');
      expect(task.notes, 'Unusually high bill — Rs 12,000 vs usual Rs 4,500');
      expect(task.priority, 2);
    });

    test('a bill with no open prediction gets its own task', () async {
      await scanBill(DateTime(2026, 9, 11, 10));
      final (_, o) = await scanBill(DateTime(2026, 10, 12, 10));
      now = DateTime(2026, 10, 12, 11);
      await atc.acceptProposal(o.proposed!.id); // predicted for 12 Nov
      final predicted = (await repos.tasks.getAll()).single;
      await repos.tasks.update(
        predicted.id,
        const TasksCompanion(status: Value('done')),
      );
      final (_, up) = await scanBill(
        DateTime(2026, 11, 12, 10),
        amount: 470000,
        due: '2026-11-25',
      );
      expect(up.upgradedTaskId, isNot(predicted.id));
      final rule = (await repos.atcRules.getById(o.proposed!.id))!;
      expect(rule.lastGeneratedPeriod, '2026-11-25');
    });

    test('M1 queue: at most one proposal per day', () async {
      await scanBill(DateTime(2026, 9, 11, 10), ref: 'A');
      await scanBill(DateTime(2026, 9, 20, 10), ref: 'B');
      await scanBill(DateTime(2026, 10, 12, 10), ref: 'A');
      await scanBill(DateTime(2026, 10, 21, 10), ref: 'B');
      now = DateTime(2026, 10, 22, 9);
      final first = await atc.takeProposalForToday();
      expect(first!.refNumber, 'A');
      expect(await atc.takeProposalForToday(), isNull, reason: 'same day');
      now = DateTime(2026, 10, 23, 9);
      expect(
        (await atc.takeProposalForToday())!.refNumber,
        'A',
        reason: 'still undecided → asked again the next day',
      );
      await atc.dismissProposal(first.id);
      now = DateTime(2026, 10, 24, 9);
      expect((await atc.takeProposalForToday())!.refNumber, 'B');
    });

    // ─────────────────────────── PBI-015 fees ───────────────────────────

    Future<Person> child(String name) => repos.persons.insert(
      PersonsCompanion.insert(name: name, relation: const Value('child')),
    );

    Future<(Document, LearningOutcome)> scanVoucher({
      required int amount,
      String? personId,
      String student = 'Ali',
      String due = '2026-12-05',
    }) async {
      final doc = await repos.documents.insert(
        DocumentsCompanion.insert(
          title: 'Fee voucher',
          docType: const Value('fee_voucher'),
          issuer: const Value('Beaconhouse'),
          personId: Value(personId),
          amountMinor: Value(amount),
          dueDate: Value(due),
        ),
      );
      await repos.extractedFields.insert(
        ExtractedFieldsCompanion.insert(
          documentId: doc.id,
          field: 'student_name',
          value: student,
        ),
      );
      return (doc, await learn.onDocumentSaved(doc));
    }

    test(
      'PBI-015 AC1: a fee rule for Ali → "Ali — school fee …, due 5th"',
      () async {
        now = DateTime(2026, 11, 8, 10);
        final ali = await child('Ali');
        final r = await atc.createRule(
          RuleInput(
            name: 'School fee',
            categoryKey: 'fees',
            dueDay: 5,
            amountMinor: 1200000,
            personId: ali.id,
          ),
        );
        expect(r.kind, 'fee');
        final task = (await repos.tasks.getWhere(
          (t) => t.atcRuleId.equals(r.id),
        )).single;
        expect(task.title, 'Ali — school fee Rs 12,000, due 5th');
        expect(task.personId, ali.id, reason: 'person chip');
        final reminder = (await repos.taskReminders.getWhere(
          (x) => x.taskId.equals(task.id),
        )).single;
        expect(
          DateTime.fromMillisecondsSinceEpoch(reminder.fireAt),
          DateTime(2026, 11, 30, 9),
          reason: '5 days before 5 Dec',
        );
      },
    );

    test('PBI-015: the first voucher proposes a fee rule', () async {
      now = DateTime(2026, 11, 8, 10);
      final ali = await child('Ali');
      final (_, o) = await scanVoucher(amount: 1200000);
      final r = o.proposed!;
      expect(
        (r.kind, r.personId, r.amountMinor, r.dueDay, r.issuer),
        ('fee', ali.id, 1200000, 5, 'Beaconhouse'),
      );
      expect(
        await atc.proposalText(r),
        'Create a fee reminder for Ali — Rs 12,000, due 5th?',
      );
    });

    test(
      'PBI-015 AC2: a new amount asks, and "yes" updates the future',
      () async {
        now = DateTime(2026, 11, 8, 10);
        final ali = await child('Ali');
        final r = await atc.createRule(
          RuleInput(
            name: 'School fee',
            categoryKey: 'fees',
            dueDay: 5,
            amountMinor: 1200000,
            personId: ali.id,
          ),
        );
        // One paid earlier fee stays as it was.
        final old = await repos.payments.insert(
          PaymentsCompanion.insert(
            title: 'School fee',
            dueDate: '2026-11-05',
            periodMonth: '2026-11-01',
            atcRuleId: Value(r.id),
            amountMinor: const Value(1200000),
            status: const Value('paid'),
          ),
        );
        final (_, o) = await scanVoucher(amount: 1350000);
        final change = o.feeChange!;
        expect(
          change.message,
          'Fee increased from 12,000 → 13,500. Update future tasks?',
        );
        await learn.applyFeeChange(change);
        expect((await repos.atcRules.getById(r.id))!.amountMinor, 1350000);
        final upcoming = (await repos.payments.getWhere(
          (p) => p.atcRuleId.equals(r.id) & p.status.equals('upcoming'),
        )).single;
        expect(upcoming.amountMinor, 1350000);
        final task = (await repos.tasks.getById(upcoming.taskId!))!;
        expect(task.title, 'Ali — school fee Rs 13,500, due 5th');
        expect((await repos.payments.getById(old.id))!.amountMinor, 1200000);
      },
    );

    test('PBI-015: the same amount asks nothing', () async {
      now = DateTime(2026, 11, 8, 10);
      final ali = await child('Ali');
      await atc.createRule(
        RuleInput(
          name: 'School fee',
          categoryKey: 'fees',
          dueDay: 5,
          amountMinor: 1200000,
          personId: ali.id,
        ),
      );
      final (_, o) = await scanVoucher(amount: 1200000);
      expect((o.feeChange, o.proposed), (null, null));
    });

    test('PBI-015 AC3: skip months {6, 7} → no June or July fee', () async {
      now = DateTime(2026, 5, 6, 10);
      final r = await atc.createRule(
        const RuleInput(
          name: 'School fee',
          categoryKey: 'fees',
          dueDay: 5,
          amountMinor: 1200000,
          skipMonths: [6, 7],
        ),
      );
      final dues = occurrencesFrom(r, now).take(2).toList();
      expect(dues, [DateTime(2026, 8, 5), DateTime(2026, 9, 5)]);
      final pay = (await repos.payments.getWhere(
        (p) => p.atcRuleId.equals(r.id),
      )).single;
      expect(pay.dueDate, '2026-08-05');
    });

    test(
      'PBI-015 AC4: a semester rule with dates generates only on them',
      () async {
        now = DateTime(2026, 11, 8, 10);
        final r = await atc.createRule(
          RuleInput(
            name: 'University fee',
            categoryKey: 'fees',
            dueDay: 1,
            amountMinor: 9000000,
            cycle: 'semester',
            scheduleDates: [
              DateTime(2027, 2, 15),
              DateTime(2026, 9, 1),
              DateTime(2027, 9, 10),
            ],
          ),
        );
        expect(occurrencesFrom(r, now).toList(), [
          DateTime(2027, 2, 15),
          DateTime(2027, 9, 10),
        ], reason: 'past date dropped, sorted');
        final pay = (await repos.payments.getWhere(
          (p) => p.atcRuleId.equals(r.id),
        )).single;
        expect(pay.dueDate, '2027-02-15');
        expect(cadenceLabel(r), 'On set dates · 1 Sep, 15 Feb, 10 Sep');
        // After it passes, the next is the next date, never a monthly one.
        now = DateTime(2027, 2, 16, 10);
        await atc.generateAll();
        final dues = (await repos.payments.getWhere(
          (p) => p.atcRuleId.equals(r.id),
        )).map((p) => p.dueDate).toList()..sort();
        expect(dues, ['2027-02-15', '2027-09-10']);
      },
    );

    test('PBI-015: a fee receipt files in Education with the child', () async {
      now = DateTime(2026, 11, 8, 10);
      final ali = await child('Ali');
      final r = await atc.createRule(
        RuleInput(
          name: 'School fee',
          categoryKey: 'fees',
          dueDay: 5,
          amountMinor: 1200000,
          personId: ali.id,
        ),
      );
      final pay = (await repos.payments.getWhere(
        (p) => p.atcRuleId.equals(r.id),
      )).single;
      final folder = await receiptFolderFor(repos, pay.id, now);
      expect(folder, ('education', ali.id));
    });
  });
}

/// Where [PaymentService.markPaid] files a receipt, without real files:
/// runs it with a stub capture that records the details.
Future<(String?, String?)> receiptFolderFor(
  Repositories repos,
  String paymentId,
  DateTime now,
) async {
  final capture = RecordingCapture(repos);
  await PaymentService(
    repos,
    capture: capture,
    now: () => now,
  ).markPaid(paymentId, receipt: capture.draft);
  final folders = await repos.folders.getAll();
  final kind = folders
      .where((f) => f.id == capture.saved!.folderId)
      .firstOrNull
      ?.kind;
  return (kind, capture.saved!.personId);
}

/// A capture service that records what it was asked to file.
class RecordingCapture extends CaptureService {
  RecordingCapture(this._r) : super(_r, Directory.systemTemp);
  final Repositories _r;
  final draft = CaptureDraft.scan(const ['receipt.jpg']);
  FilingDetails? saved;

  @override
  Future<Document> save(CaptureDraft d, FilingDetails details) async {
    saved = details;
    return _r.documents.insert(
      DocumentsCompanion.insert(
        title: details.title,
        folderId: Value(details.folderId),
        personId: Value(details.personId),
      ),
    );
  }
}
