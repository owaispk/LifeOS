// PBI-038 F-05 + F-06 widget tests: a one-off bill from the expense sheet
// lands in the Forecast; "Mark as unpaid" reverses a payment long after
// the 5-second Undo, from the Forecast and from the logged expense.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget_test_utils.dart';
import 'chain_forecast_screen_test.dart' show feeDueToday, makeFakes;

Future<void> openForecast(WidgetTester tester) async {
  await openTab(tester, 'Money');
  await tester.tap(find.text('Forecast'));
  await tester.pumpAndSettle();
}

void main() {
  appTest('Forecast: mark paid, then mark as unpaid after the Undo is gone', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    await openForecast(tester);

    await tester.tap(find.byKey(ValueKey('mark-paid-${pay.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 6)); // Undo has expired
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('mark-paid-${pay.id}')), findsNothing);

    await tester.tap(find.byKey(ValueKey('mark-unpaid-${pay.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Mark School fee as unpaid?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-unpaid-confirm')));
    await settle(tester);

    expect(find.text('Marked as unpaid'), findsOneWidget);
    expect(
      find.text('Rs 12,000 total · Rs 0 paid · Rs 12,000 remaining'),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('mark-paid-${pay.id}')), findsOneWidget);
    final expenses = await tester.runAsync(app.repos.expenses.getAll);
    expect(expenses, isEmpty);
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);

  appTest('the logged expense offers Mark as unpaid instead of Delete', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    await openForecast(tester);
    await tester.tap(find.byKey(ValueKey('mark-paid-${pay.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    final expense = (await tester.runAsync(app.repos.expenses.getAll))!.single;
    await tester.tap(find.byKey(ValueKey('expense-${expense.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense-delete')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('expense-mark-unpaid')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mark-unpaid-confirm')));
    await settle(tester);

    expect(find.byKey(const ValueKey('expense-amount')), findsNothing);
    expect(find.byKey(ValueKey('expense-${expense.id}')), findsNothing);
    final back = await tester.runAsync(
      () => app.repos.payments.getById(pay.id),
    );
    expect(back!.status, 'upcoming');
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);

  appTest('Not paid yet? → a bill due on the 20th shows in the Forecast', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openTab(tester, 'Money');
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-action-expense')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('expense-to-bill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('expense-amount')), findsNothing);
    expect(find.byKey(const ValueKey('bill-save')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('bill-name')), 'Plumber');
    await tester.enterText(find.byKey(const ValueKey('bill-amount')), '3,500');
    await tester.pump();
    final save = find.byKey(const ValueKey('bill-save'));
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'a due date is required',
    );
    await tester.tap(find.byKey(const ValueKey('bill-due')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await settle(tester);

    expect(find.text('Bill added for 20 Nov'), findsOneWidget);
    final pays = (await tester.runAsync(app.repos.payments.getAll))!;
    expect(
      (pays.single.title, pays.single.dueDate, pays.single.amountMinor),
      ('Plumber', '2026-11-20', 350000),
    );
    expect(pays.single.atcRuleId, isNull, reason: 'no Auto Tasks rule');

    await tester.tap(find.text('Forecast'));
    await tester.pumpAndSettle();
    expect(find.text('Plumber'), findsOneWidget);
    expect(
      find.text('Rs 3,500 total · Rs 0 paid · Rs 3,500 remaining'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);
}
