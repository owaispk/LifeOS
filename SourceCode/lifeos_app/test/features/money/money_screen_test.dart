// PBI-018 widget tests: Month Overview, Add/Edit Expense, month navigation.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../../widget_test_utils.dart';

Future<String> categoryId(TestApp app, WidgetTester tester, String key) async {
  final cats = await tester.runAsync(app.repos.categories.getAll);
  return cats!.firstWhere((c) => c.systemKey == key).id;
}

Future<Expense> addExpense(
  TestApp app,
  WidgetTester tester,
  int amountMinor,
  String spentOn, {
  String? categoryId,
  String? paymentId,
}) {
  return app.write(
    tester,
    () => app.repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: amountMinor,
        spentOn: spentOn,
        categoryId: Value(categoryId),
        paymentId: Value(paymentId),
      ),
    ),
  );
}

String totalText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('month-total'))).data!;

String monthLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('month-label'))).data!;

void main() {
  appTest('empty month shows Rs 0 and an Add expense empty state', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openTab(tester, 'Money');
    expect(monthLabel(tester), 'November 2026');
    expect(totalText(tester), 'Rs 0');
    expect(find.text('No expenses in November 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('month-delta')), findsNothing);
  });

  appTest('AC1/AC3: adding Rs 1,250 shows it, totals it, delta is "New"', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openTab(tester, 'Money');
    await tester.tap(find.text('💸 Add expense'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '1,250',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('expense-category-utilities')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('expense-save')));
    await settle(tester);

    expect(totalText(tester), 'Rs 1,250');
    expect(find.text('Utilities'), findsWidgets); // breakdown row + list row
    expect(find.byKey(const ValueKey('category-bar')), findsOneWidget);
    expect(find.text('New · nothing in Oct'), findsOneWidget);

    final stored = await tester.runAsync(app.repos.expenses.getAll);
    expect(stored!.single.amountMinor, 125000);
  });

  appTest('rejects an amount of 0', (tester, app) async {
    await useTallScreen(tester);
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-action-expense')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '0');
    await tester.pump();
    expect(find.text('Enter an amount above 0'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const ValueKey('expense-save')),
    );
    expect(save.onPressed, isNull);
  });

  appTest('AC2: breakdown rows add up to the total', (tester, app) async {
    await useTallScreen(tester);
    final rent = await categoryId(app, tester, 'rent');
    final util = await categoryId(app, tester, 'utilities');
    await addExpense(app, tester, 4500000, '2026-11-01', categoryId: rent);
    await addExpense(app, tester, 485000, '2026-11-03', categoryId: util);
    await addExpense(app, tester, 15000, '2026-11-04');
    await openTab(tester, 'Money');

    expect(totalText(tester), 'Rs 50,000');
    expect(find.byKey(ValueKey('category-row-$rent')), findsOneWidget);
    expect(find.byKey(ValueKey('category-row-$util')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-row-none')), findsOneWidget);
    expect(find.text('90%'), findsOneWidget); // 45,000 of 50,000
    // Expenses are listed by day, each with its total (PBI-038 F-02).
    for (final day in ['2026-11-01', '2026-11-03', '2026-11-04']) {
      expect(find.byKey(ValueKey('money-day-$day')), findsOneWidget);
    }
    expect(find.text('Rs 45,000'), findsWidgets);
  });

  appTest('AC4: month navigation updates every figure', (tester, app) async {
    await useTallScreen(tester);
    await addExpense(app, tester, 100000, '2026-10-12');
    await addExpense(app, tester, 112000, '2026-11-02');
    await openTab(tester, 'Money');

    expect(totalText(tester), 'Rs 1,120');
    expect(find.text('12% vs Oct'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.byKey(const ValueKey('month-next')),
    );
    expect(next.onPressed, isNull, reason: 'cannot go past this month');

    await tester.tap(find.byKey(const ValueKey('month-prev')));
    await tester.pumpAndSettle();
    expect(monthLabel(tester), 'October 2026');
    expect(totalText(tester), 'Rs 1,000');
    expect(find.text('New · nothing in Sep'), findsOneWidget);
    expect(find.byKey(const ValueKey('money-day-2026-10-12')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('money-coming-up')),
      findsNothing,
      reason: 'bills still to pay belong to the current month',
    );

    await tester.tap(find.byKey(const ValueKey('month-prev')));
    await tester.pumpAndSettle();
    expect(monthLabel(tester), 'September 2026');
    expect(totalText(tester), 'Rs 0');
    expect(find.text('No expenses in September 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('month-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('month-next')));
    await tester.pumpAndSettle();
    expect(monthLabel(tester), 'November 2026');
    expect(totalText(tester), 'Rs 1,120');
  });

  appTest('edit and delete a manual expense', (tester, app) async {
    await useTallScreen(tester);
    final e = await addExpense(app, tester, 50000, '2026-11-05');
    await openTab(tester, 'Money');

    await tester.tap(find.byKey(ValueKey('expense-${e.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Edit expense'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('expense-amount')), '650');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('expense-save')));
    await settle(tester);
    expect(totalText(tester), 'Rs 650');

    await tester.tap(find.byKey(ValueKey('expense-${e.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expense-delete')));
    await settle(tester);
    expect(totalText(tester), 'Rs 0');
  });

  appTest('AC5: a payment-linked expense shows ⚡ and offers no Delete', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final payment = await app.write(
      tester,
      () => app.repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'School fee',
          dueDate: '2026-11-05',
          periodMonth: '2026-11-01',
        ),
      ),
    );
    final e = await addExpense(
      app,
      tester,
      1200000,
      '2026-11-05',
      paymentId: payment.id,
    );
    await openTab(tester, 'Money');
    expect(find.text('⚡'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('expense-${e.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense-delete')), findsNothing);
    expect(find.byKey(const ValueKey('expense-linked-note')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('expense-amount')),
      '13,500',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('expense-save')));
    await settle(tester);

    final stored = await tester.runAsync(
      () => app.repos.expenses.getById(e.id),
    );
    expect(stored!.amountMinor, 1350000);
    expect(stored.paymentId, payment.id);
  });
}
