// PBI-038 F-01: Tasks → ⋮ → Completed lists done tasks by day; "Mark as
// not done" brings one back, and a paid payment's task reverses the
// payment instead of leaving Money and Tasks out of step.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/tasks/data/task_service.dart';

import '../../widget_test_utils.dart';
import '../money/chain_forecast_screen_test.dart' show feeDueToday, makeFakes;
import 'tasks_screen_test.dart' show addTask, taskTitle;

Future<void> openCompleted(WidgetTester tester) async {
  await openTab(tester, 'Tasks');
  await tester.tap(find.byKey(const ValueKey('tasks-overflow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tasks-completed')));
  await tester.pumpAndSettle();
}

void main() {
  appTest('empty: an invitation, not a blank screen', (tester, app) async {
    await openCompleted(tester);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-empty')), findsOneWidget);
  });

  appTest('a ticked-off task is listed under Today and can come back', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final t = await addTask(app, tester, 'Call the bank', due: testNow);
    await app.write(
      tester,
      () => TaskService(app.repos, now: () => testNow).complete(t.id),
    );

    await openCompleted(tester);
    expect(find.byKey(ValueKey('completed-${t.id}')), findsOneWidget);
    expect(find.text('Call the bank'), findsOneWidget);
    expect(find.text('Done at 10:00 AM'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('reopen-${t.id}')));
    await settle(tester);
    expect(find.text('Back in your tasks'), findsOneWidget);
    expect(find.byKey(ValueKey('completed-${t.id}')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(taskTitle('Call the bank'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  appTest('a paid payment task asks to mark the payment unpaid', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final pay = await feeDueToday(app, tester);
    await openTab(tester, 'Tasks');
    await tester.tap(find.byKey(ValueKey('complete-${pay.taskId}')));
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tasks-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tasks-completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('reopen-${pay.taskId}')));
    await tester.pumpAndSettle();
    expect(find.text('Mark School fee as unpaid?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-unpaid-confirm')));
    await settle(tester);

    final back = await tester.runAsync(
      () => app.repos.payments.getById(pay.id),
    );
    expect(back!.status, 'upcoming');
    final expenses = await tester.runAsync(app.repos.expenses.getAll);
    expect(expenses, isEmpty);
    await tester.pump(const Duration(seconds: 6));
  }, capture: makeFakes);
}
