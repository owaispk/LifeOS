// PBI-013 / PBI-017 widget tests: add a rule, groups, pause, upgrade
// prompt, detail, delete.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget_test_utils.dart';

Future<void> openRules(WidgetTester tester) async {
  await openTab(tester, 'More');
  await tester.tap(find.byKey(const ValueKey('more-atc')));
  await tester.pumpAndSettle();
}

Future<void> addRule(
  WidgetTester tester,
  String preset, {
  String? amount,
}) async {
  await tester.tap(find.byKey(const ValueKey('atc-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('preset-$preset')));
  await tester.pumpAndSettle();
  if (amount != null) {
    await tester.enterText(find.byKey(const ValueKey('rule-amount')), amount);
    await tester.pump();
  }
  await tester.ensureVisible(find.byKey(const ValueKey('rule-save')));
  await tester.tap(find.byKey(const ValueKey('rule-save')));
  await settle(tester);
}

void main() {
  appTest('AC1: adding Rent creates the rule, its task and payment', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openRules(tester);
    expect(find.text('Let LifeOS remember your payments'), findsOneWidget);

    await addRule(tester, 'rent', amount: '45,000');
    expect(find.text('Rent — Rs 45,000'), findsOneWidget);
    expect(find.text('Monthly · 1st · Next Tue, 1 Dec'), findsOneWidget);
    expect(
      find.text('⚡ ATC created 1 task for you this month'),
      findsOneWidget,
    );
    final payments = await tester.runAsync(app.repos.payments.getAll);
    expect(payments!.single.amountMinor, 4500000);
  });

  appTest('PBI-017 AC1: rules are grouped', (tester, app) async {
    await useTallScreen(tester);
    await openRules(tester);
    await addRule(tester, 'utility');
    await addRule(tester, 'fees', amount: '12,000');
    await addRule(tester, 'internet', amount: '3,000');
    expect(find.byKey(const ValueKey('atc-group-Bills')), findsOneWidget);
    expect(find.byKey(const ValueKey('atc-group-Fees')), findsOneWidget);
    expect(find.byKey(const ValueKey('atc-group-Fixed')), findsOneWidget);
  });

  appTest('AC6: the 4th rule shows the upgrade prompt', (tester, app) async {
    await useTallScreen(tester);
    await openRules(tester);
    for (final p in ['rent', 'internet', 'mobile']) {
      await addRule(tester, p, amount: '1,000');
    }
    await addRule(tester, 'subscription', amount: '1,100');
    expect(find.byKey(const ValueKey('upgrade-prompt')), findsOneWidget);
    expect(
      find.text('Free plan includes 3 auto-rules — Premium removes the limit.'),
      findsOneWidget,
    );
    final rules = await tester.runAsync(app.repos.atcRules.getAll);
    expect(rules, hasLength(3));
  });

  appTest('PBI-017 AC2: the pause switch takes effect at once', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openRules(tester);
    await addRule(tester, 'rent', amount: '45,000');
    final rule = (await tester.runAsync(app.repos.atcRules.getAll))!.single;
    await tester.tap(find.byKey(ValueKey('rule-switch-${rule.id}')));
    await settle(tester);
    final paused = await tester.runAsync(
      () => app.repos.atcRules.getById(rule.id),
    );
    expect(paused!.status, 'paused');
    expect(find.textContaining('Paused'), findsOneWidget);
  });

  appTest('PBI-017: detail shows history; delete keeps the task', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openRules(tester);
    await addRule(tester, 'rent', amount: '45,000');
    final rule = (await tester.runAsync(app.repos.atcRules.getAll))!.single;
    await tester.tap(find.byKey(ValueKey('rule-${rule.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Created 1 task · 0 paid on time'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('detail-rule-delete')),
    );
    await tester.tap(find.byKey(const ValueKey('detail-rule-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-rule-delete')));
    await settle(tester);
    expect(find.text('Let LifeOS remember your payments'), findsOneWidget);
    final tasks = await tester.runAsync(app.repos.tasks.getAll);
    expect(tasks!.single.atcRuleId, isNull);
  });
}
