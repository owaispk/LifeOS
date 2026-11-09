// PBI-014 / PBI-015 widget tests: the M1 proposal dialog (shown by the
// shell, once a day), the fee-change prompt after scanning a voucher, and
// the missed-bill banner.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:lifeos_app/features/capture/ocr/field_extractor.dart';
import 'package:path/path.dart' as p;

import '../../fakes.dart';
import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

late Directory tmp;
late CaptureFakes fakes;

CaptureFakes makeFakes() {
  tmp = Directory.systemTemp.createTempSync('lifeos_learn_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a thumbnail open.
    }
  });
  fakes = CaptureFakes(Directory(p.join(tmp.path, 'vault'))..createSync());
  return fakes;
}

String fixture(String name) =>
    File('test/fixtures/ocr/$name.txt').readAsStringSync();

Future<AtcRule> proposedBill(TestApp app, WidgetTester tester, String ref) =>
    app.write(
      tester,
      () => app.repos.atcRules.insert(
        AtcRulesCompanion.insert(
          kind: 'bill_pattern',
          name: 'Electricity bill (K-Electric)',
          issuer: const Value('K-Electric'),
          refNumber: Value(ref),
          dueDay: const Value(12),
          expectedWindow: const Value('{"from":10,"to":14}'),
          remindDaysBefore: const Value(0),
          stats: const Value(
            '{"label":"electricity","min":400000,"max":600000}',
          ),
        ),
      ),
    );

final proposal = find.byKey(const ValueKey('atc-proposal'));

void main() {
  appTest('M1: "Yes, remind me" turns the rule on and creates the task', (
    tester,
    app,
  ) async {
    final r = await proposedBill(app, tester, 'A');
    await settle(tester);
    expect(proposal, findsOneWidget);
    expect(
      find.text(
        'Your electricity bill usually arrives the 10th–14th. '
        'Create a monthly reminder?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('atc-proposal-yes')));
    await settle(tester);
    expect(proposal, findsNothing);
    expect(find.text('⚡ Auto-reminder is on'), findsOneWidget);
    final stored = await tester.runAsync(
      () => app.repos.atcRules.getById(r.id),
    );
    expect(stored!.status, 'active');
    final tasks = await tester.runAsync(app.repos.tasks.getAll);
    expect(tasks!.single.title, 'Expect electricity bill (~Rs 4,000–6,000)');
  });

  appTest('M1: "No thanks" dismisses; a 2nd proposal waits for tomorrow', (
    tester,
    app,
  ) async {
    final a = await proposedBill(app, tester, 'A');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('atc-proposal-no')));
    await settle(tester);
    final stored = await tester.runAsync(
      () => app.repos.atcRules.getById(a.id),
    );
    expect(stored!.status, 'dismissed');

    await proposedBill(app, tester, 'B');
    await settle(tester);
    expect(proposal, findsNothing, reason: 'one proposal per day');
    final tasks = await tester.runAsync(app.repos.tasks.getAll);
    expect(tasks, isEmpty, reason: 'never created silently');
  });

  appTest('PBI-015 AC2: a voucher with a new amount asks to update', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final text = fixture('fee_voucher_1'); // Rs 12,000
    final student = extractFields(
      'fee_voucher',
      text,
    )[Fields.studentName]!.value;
    final child = await app.write(
      tester,
      () => app.repos.persons.insert(
        PersonsCompanion.insert(name: student, relation: const Value('child')),
      ),
    );
    final rule = await app.write(
      tester,
      () => AtcService(app.repos, now: () => testNow).createRule(
        RuleInput(
          name: 'School fee',
          categoryKey: 'fees',
          dueDay: 5,
          amountMinor: 1000000, // Rs 10,000 before the increase
          personId: child.id,
        ),
      ),
    );

    fakes.reader.texts.add(text);
    final page = File(p.join(tmp.path, 'v.jpg'))
      ..writeAsBytesSync(
        img.encodeJpg(fakeDocument(width: 300, height: 400), quality: 80),
      );
    fakes.scanner.results.add([page.path]);
    await openTab(tester, 'Vault');
    await tester.tap(find.byKey(const ValueKey('vault-scan')));
    final save = find.byKey(const ValueKey('review-save'));
    await pumpUntilFound(tester, save);
    await pumpUntilGone(tester, find.byKey(const ValueKey('review-reading')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpUntilFound(tester, find.byKey(const ValueKey('fee-change')));
    expect(
      find.text('Fee increased from 10,000 → 12,000. Update future tasks?'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('fee-change-update')));
    await pumpUntilFound(tester, find.text('Saved to Vault'));
    final stored = await tester.runAsync(
      () => app.repos.atcRules.getById(rule.id),
    );
    expect(stored!.amountMinor, 1200000);
    final tasks = await tester.runAsync(app.repos.tasks.getAll);
    expect(tasks!.single.title, '$student — school fee Rs 12,000, due 5th');
  }, capture: makeFakes);

  appTest('missed month: the rule offers "I\'ll scan it" or Pause', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final r = await app.write(
      tester,
      () => app.repos.atcRules.insert(
        AtcRulesCompanion.insert(
          kind: 'bill_pattern',
          name: 'Gas bill (SSGC)',
          issuer: const Value('SSGC'),
          dueDay: const Value(2),
          expectedWindow: const Value('{"from":1,"to":3}'),
          status: const Value('active'),
          stats: const Value('{"label":"gas"}'),
          lastGeneratedPeriod: const Value('2026-11-02'),
        ),
      ),
    );
    await app.write(tester, () async {
      final t = await app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Expect gas bill',
          atcRuleId: Value(r.id),
          dueAt: Value(DateTime(2026, 11, 2).millisecondsSinceEpoch),
        ),
      );
      await app.repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'Gas bill (SSGC)',
          dueDate: '2026-11-02',
          periodMonth: '2026-11-01',
          taskId: Value(t.id),
          atcRuleId: Value(r.id),
        ),
      );
    });
    await openTab(tester, 'More');
    await tester.tap(find.byKey(const ValueKey('more-atc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('rule-${r.id}')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No gas bill this month — did you miss it, or should I pause this '
        'reminder?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('missed-bill-pause')));
    await settle(tester);
    final stored = await tester.runAsync(
      () => app.repos.atcRules.getById(r.id),
    );
    expect(stored!.status, 'paused');
    expect(find.byKey(const ValueKey('missed-bill')), findsNothing);
  });
}
