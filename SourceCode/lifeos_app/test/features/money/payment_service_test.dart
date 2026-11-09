// PBI-016: the completion chain on a real database + real receipt files.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/money/data/payment_service.dart';
import 'package:lifeos_app/features/reminders/data/reminder_service.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../capture/image_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 8, 10);
  late AppDatabase db;
  late Repositories repos;
  late Directory tmp;
  late PaymentService payments;
  late AtcService atc;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('lifeos_pay_');
    await openLocalData(db);
    repos = await Repositories.open(
      db,
      clock: () => now.millisecondsSinceEpoch,
    );
    final capture = CaptureService(
      repos,
      Directory(p.join(tmp.path, 'vault')),
      now: () => now,
    );
    payments = PaymentService(repos, capture: capture, now: () => now);
    atc = AtcService(repos, now: () => now);
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<Payment> feeRule({int? amount = 1200000, int? total}) async {
    final r = await atc.createRule(
      RuleInput(
        name: 'School fee',
        categoryKey: total == null ? 'fees' : 'installment',
        dueDay: 20,
        amountMinor: amount,
        installmentTotal: total,
      ),
    );
    return (await repos.payments.getWhere((x) => x.atcRuleId.equals(r.id)))
        .single;
  }

  Future<CaptureDraft> receipt() async {
    final f = File(p.join(tmp.path, 'receipt.jpg'))
      ..writeAsBytesSync(jpeg(fakeDocument(width: 200, height: 260)));
    return CaptureDraft.scan([f.path]);
  }

  test('AC1: Skip → one expense with the rule category, no document', () async {
    final pay = await feeRule();
    final r = await payments.markPaid(pay.id);

    final paid = (await repos.payments.getById(pay.id))!;
    expect(
      (paid.status, paid.paidAt),
      ('paid', now.toUtc().millisecondsSinceEpoch),
    );
    final exp = (await repos.expenses.getAll()).single;
    final fees = (await repos.categories.getAll()).firstWhere(
      (c) => c.systemKey == 'fees',
    );
    expect(
      (exp.amountMinor, exp.categoryId, exp.paymentId, exp.spentOn),
      (1200000, fees.id, pay.id, '2026-11-08'),
    );
    expect(exp.id, r.expenseId);
    expect(await repos.documents.getAll(), isEmpty);
    expect((await repos.tasks.getById(pay.taskId!))!.status, 'done');
  });

  test(
    'AC2: with a receipt → document linked from payment and expense',
    () async {
      final pay = await feeRule();
      final r = await payments.markPaid(pay.id, receipt: await receipt());

      final doc = (await repos.documents.getAll()).single;
      expect(doc.title, 'Receipt — School fee');
      expect(doc.docType, 'receipt');
      // A school-fee receipt files under Education since PBI-015.
      final education = (await repos.folders.getAll()).firstWhere(
        (f) => f.kind == 'education',
      );
      expect(doc.folderId, education.id);
      expect((await repos.payments.getById(pay.id))!.receiptDocumentId, doc.id);
      expect((await repos.expenses.getAll()).single.receiptDocumentId, doc.id);
      expect(r.receiptDocumentId, doc.id);
    },
  );

  test(
    'AC3: a failure rolls back everything, including receipt files',
    () async {
      final pay = await feeRule();
      // Point the payment at a category that doesn't exist, so the expense
      // insert fails on its foreign key after the receipt was saved.
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.customStatement(
        "UPDATE payments SET category_id = 'missing' WHERE id = '${pay.id}'",
      );
      await db.customStatement('PRAGMA foreign_keys = ON');

      await expectLater(
        payments.markPaid(pay.id, receipt: await receipt()),
        throwsA(anything),
      );
      expect((await repos.payments.getById(pay.id))!.status, 'upcoming');
      expect(await repos.expenses.getAll(), isEmpty);
      expect(await repos.documents.getAll(includeDeleted: true), isEmpty);
      expect((await repos.tasks.getById(pay.taskId!))!.status, 'open');
      final vault = Directory(p.join(tmp.path, 'vault'));
      expect(
        vault.existsSync() ? vault.listSync() : const [],
        isEmpty,
        reason: 'no orphan receipt files',
      );
    },
  );

  test('AC4: paying twice creates no second expense', () async {
    final pay = await feeRule();
    await payments.markPaid(pay.id);
    final again = await payments.markPaid(pay.id);
    expect(again.alreadyPaid, isTrue);
    expect(await repos.expenses.getAll(), hasLength(1));
  });

  test('AC5: undo reverses payment, expense, receipt and task', () async {
    final pay = await feeRule();
    final r = await payments.markPaid(pay.id, receipt: await receipt());
    await payments.undo(r);

    final back = (await repos.payments.getById(pay.id))!;
    expect(
      (back.status, back.paidAt, back.receiptDocumentId),
      ('upcoming', null, null),
    );
    expect(await repos.expenses.getAll(), isEmpty);
    expect(await repos.documents.getAll(), isEmpty, reason: 'receipt → Trash');
    expect(await repos.documents.getAll(includeDeleted: true), hasLength(1));
    expect((await repos.tasks.getById(pay.taskId!))!.status, 'open');
  });

  test('unknown amounts must be entered first', () async {
    final pay = await feeRule(amount: null);
    await expectLater(
      payments.markPaid(pay.id),
      throwsA(isA<MissingAmountException>()),
    );
    await payments.markPaid(pay.id, amountMinor: 1350000);
    expect((await repos.expenses.getAll()).single.amountMinor, 1350000);
    expect((await repos.payments.getById(pay.id))!.amountMinor, 1350000);
  });

  test(
    'PBI-013 AC4: the last installment ends the rule; undo re-opens it',
    () async {
      final pay = await feeRule(total: 1);
      final r = await payments.markPaid(pay.id);
      var rule = (await repos.atcRules.getById(pay.atcRuleId!))!;
      expect((rule.installmentDone, rule.status), (1, 'ended'));

      await payments.undo(r);
      rule = (await repos.atcRules.getById(pay.atcRuleId!))!;
      expect((rule.installmentDone, rule.status), (0, 'active'));
    },
  );

  test('notification Paid ✓ runs the same chain (no receipt)', () async {
    final pay = await feeRule();
    await repos.taskReminders.insert(
      TaskRemindersCompanion.insert(
        taskId: pay.taskId!,
        fireAt: DateTime(2026, 11, 15, 9).millisecondsSinceEpoch,
      ),
    );
    final reminder = (await repos.taskReminders.getAll()).last;
    final payload = PlannedNotification(
      id: 1,
      reminderId: reminder.id,
      taskId: pay.taskId!,
      kind: ReminderKind.payment,
      fireAt: DateTime(2026, 11, 15, 9),
      title: 't',
      body: 'b',
    ).payload;
    await ReminderService(
      repos,
      now: () => now,
    ).handleAction(ReminderActions.paid, payload);
    expect((await repos.payments.getById(pay.id))!.status, 'paid');
    expect(await repos.expenses.getAll(), hasLength(1));
  });
}
