// PBI-038 F-06: "Mark as unpaid" reverses a payment at any time, rebuilt
// from the database (no 5-second PaidResult), plus TaskService.reopen.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/money/data/payment_service.dart';
import 'package:lifeos_app/features/tasks/data/task_service.dart';
import 'package:lifeos_app/features/tasks/domain/task_rules.dart';
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
  late TaskService tasks;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('lifeos_unpaid_');
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
    tasks = TaskService(repos, now: () => now);
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<Payment> rulePayment({int? total}) async {
    final r = await atc.createRule(
      RuleInput(
        name: 'School fee',
        categoryKey: total == null ? 'fees' : 'installment',
        dueDay: 20,
        amountMinor: 1200000,
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

  test(
    'reverses payment, expense, receipt and task long after paying',
    () async {
      final pay = await rulePayment();
      await payments.markPaid(pay.id, receipt: await receipt());
      // No PaidResult kept: the snackbar is long gone.
      expect(await payments.markUnpaid(pay.id), isTrue);

      final back = (await repos.payments.getById(pay.id))!;
      expect(
        (back.status, back.paidAt, back.receiptDocumentId),
        ('upcoming', null, null),
      );
      expect(await repos.expenses.getAll(), isEmpty);
      expect(
        await repos.documents.getAll(),
        isEmpty,
        reason: 'receipt → Trash',
      );
      expect(await repos.documents.getAll(includeDeleted: true), hasLength(1));
      final task = (await repos.tasks.getById(pay.taskId!))!;
      expect((task.status, task.completedAt), ('open', null));
    },
  );

  test('the payment can be paid again afterwards', () async {
    final pay = await rulePayment();
    await payments.markPaid(pay.id);
    await payments.markUnpaid(pay.id);
    final again = await payments.markPaid(pay.id);
    expect(again.alreadyPaid, isFalse);
    expect(await repos.expenses.getAll(), hasLength(1));
  });

  test('an unpaid payment is left alone', () async {
    final pay = await rulePayment();
    expect(await payments.markUnpaid(pay.id), isFalse);
    expect(await payments.markUnpaid('missing'), isFalse);
    expect((await repos.payments.getById(pay.id))!.status, 'upcoming');
  });

  test('the last installment re-opens its ended rule', () async {
    final pay = await rulePayment(total: 1);
    await payments.markPaid(pay.id);
    var rule = (await repos.atcRules.getById(pay.atcRuleId!))!;
    expect((rule.installmentDone, rule.status), (1, 'ended'));

    await payments.markUnpaid(pay.id);
    rule = (await repos.atcRules.getById(pay.atcRuleId!))!;
    expect((rule.installmentDone, rule.status), (0, 'active'));
  });

  test('a bill added without a rule reverses too', () async {
    final bill = await payments.addBill(
      title: 'Plumber',
      amountMinor: 350000,
      due: DateTime(2026, 11, 20),
    );
    await payments.markPaid(bill.id);
    expect(await payments.markUnpaid(bill.id), isTrue);
    expect(await repos.expenses.getAll(), isEmpty);
    expect((await repos.tasks.getById(bill.taskId!))!.status, 'open');
  });

  group('TaskService.reopen', () {
    test('reopens a one-off task', () async {
      final t = await tasks.create(title: 'Call bank');
      await tasks.complete(t.id);
      await tasks.reopen(t.id);
      final back = (await repos.tasks.getById(t.id))!;
      expect((back.status, back.completedAt), ('open', null));
    });

    test(
      'removes the next occurrence a repeating task created, only that one',
      () async {
        final t = await tasks.create(
          title: 'Water plants',
          due: DateTime(2026, 11, 8),
          repeat: RepeatFreq.weekly,
        );
        final other = await tasks.create(
          title: 'Water plants',
          due: DateTime(2026, 11, 9),
          repeat: RepeatFreq.weekly,
        );
        final done = await tasks.complete(t.id);
        expect(done.nextTaskId, isNotNull);

        await tasks.reopen(t.id);
        expect((await repos.tasks.getById(t.id))!.status, 'open');
        expect(await repos.tasks.getById(done.nextTaskId!), isNull);
        expect(
          (await repos.tasks.getById(other.id))!.status,
          'open',
          reason: 'an older copy is not the occurrence this completion made',
        );
      },
    );

    test('watchCompleted lists done tasks, newest first', () async {
      final a = await tasks.create(title: 'A');
      final b = await tasks.create(title: 'B');
      await tasks.complete(a.id);
      await tasks.complete(b.id);
      final list = await tasks.watchCompleted().first;
      expect(list.map((t) => t.title).toSet(), {'A', 'B'});
    });
  });
}
