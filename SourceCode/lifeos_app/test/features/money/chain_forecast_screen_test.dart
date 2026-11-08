// PBI-016 + PBI-019 widget tests: completing a payment task runs the chain
// (sheet, receipt, confirmations, undo); Forecast shows totals, status,
// mark-paid and the salary insight.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/atc/data/atc_service.dart';
import 'package:path/path.dart' as p;

import '../../fakes.dart';
import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

late CaptureFakes fakes;
late Directory tmp;
CaptureFakes makeFakes() {
  tmp = Directory.systemTemp.createTempSync('lifeos_chain_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold an image open.
    }
  });
  fakes = CaptureFakes(Directory(p.join(tmp.path, 'vault'))..createSync());
  return fakes;
}

/// A fee rule due today (8 Nov, testNow) → a payment task in Today.
Future<Payment> feeDueToday(
  TestApp app,
  WidgetTester tester, {
  int? amount = 1200000,
}) async {
  final rule = await app.write(
    tester,
    () => AtcService(app.repos, now: () => testNow).createRule(
      RuleInput(
        name: 'School fee',
        categoryKey: 'fees',
        dueDay: 8,
        amountMinor: amount,
      ),
    ),
  );
  final pays = await tester.runAsync(
    () => app.repos.payments.getWhere((x) => x.atcRuleId.equals(rule.id)),
  );
  return pays!.single;
}

Future<void> completeFromToday(WidgetTester tester, Payment pay) async {
  await openTab(tester, 'Tasks');
  await tester.tap(find.byKey(ValueKey('complete-${pay.taskId}')));
  await tester.pump(const Duration(milliseconds: 300));
  await settle(tester);
}

void main() {
  appTest('checking off a payment task → sheet → Skip → logged; Undo', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    await completeFromToday(tester, pay);

    expect(find.byKey(const ValueKey('paid-sheet')), findsOneWidget);
    expect(find.text('✓ School fee — Rs 12,000 paid'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);

    expect(find.text('✓ Paid · Logged in Money'), findsOneWidget);
    final paid = await tester.runAsync(
      () => app.repos.payments.getById(pay.id),
    );
    expect(paid!.status, 'paid');
    expect(await tester.runAsync(app.repos.expenses.getAll), hasLength(1));

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final undone = await tester.runAsync(
      () => app.repos.payments.getById(pay.id),
    );
    expect(undone!.status, 'upcoming');
    expect(await tester.runAsync(app.repos.expenses.getAll), isEmpty);
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);

  appTest('Scan receipt → Filed in Vault · Logged in Money', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    final page = File(p.join(tmp.path, 'r.jpg'))
      ..writeAsBytesSync(jpeg(fakeDocument(width: 200, height: 260)));
    fakes.scanner.results.add([page.path]);
    await completeFromToday(tester, pay);
    await tester.tap(find.byKey(const ValueKey('paid-scan')));
    await pumpUntilFound(
      tester,
      find.text('✓ Paid · Filed in Vault · Logged in Money'),
    );
    final docs = await tester.runAsync(app.repos.documents.getAll);
    expect(docs!.single.title, 'Receipt — School fee');
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);

  appTest('unknown amount: the sheet asks for it first', (tester, app) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester, amount: null);
    await completeFromToday(tester, pay);
    expect(find.text('✓ School fee — how much did you pay?'), findsOneWidget);
    final skip = find.byKey(const ValueKey('paid-skip'));
    expect(tester.widget<FilledButton>(skip).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('paid-amount')), '13,500');
    await tester.pump();
    await tester.tap(skip);
    await settle(tester);
    final exp = await tester.runAsync(app.repos.expenses.getAll);
    expect(exp!.single.amountMinor, 1350000);
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);

  appTest('Forecast: digest, totals, due dots, mark paid, salary', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    await openTab(tester, 'Money');
    await tester.tap(find.text('Forecast'));
    await tester.pumpAndSettle();

    expect(
      find.text('November fixed payments: Rs 12,000 across 1 item'),
      findsOneWidget,
    );
    expect(
      find.text('Rs 12,000 total · Rs 0 paid · Rs 12,000 remaining'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('due-dot-8')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('mark-paid-${pay.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);
    expect(
      find.text('Rs 12,000 total · Rs 12,000 paid · Rs 0 remaining'),
      findsOneWidget,
    );
    expect(find.textContaining('Paid ✓'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('forecast-set-salary')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('salary-amount')),
      '150,000',
    );
    await tester.tap(find.byKey(const ValueKey('salary-save')));
    await settle(tester);
    expect(
      find.text('8% of income goes to fixed payments'),
      findsOneWidget,
      reason: '12,000 / 150,000 = 8%',
    );
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);
}
