// PBI-011 widget tests: dialog on save (AC1, AC3), heatmap (AC5).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/tasks/domain/task_rules.dart';

import '../../widget_test_utils.dart';

// testNow is Sunday 8 Nov 2026 → "Tomorrow" in the sheet is Monday 9 Nov.
final monday = DateTime(2026, 11, 9);

Future<void> seed(TestApp app, WidgetTester tester, DateTime day, int min) =>
    app.write(
      tester,
      () => app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Existing $min',
          dueAt: Value(day.millisecondsSinceEpoch),
          durationMin: Value(min),
        ),
      ),
    );

/// Opens New Task, types [title], picks Tomorrow and a 1 h duration, saves.
Future<void> addOneHourTomorrow(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quick-action-task')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('new-task-title')), title);
  await tester.pump();
  await tester.tap(find.text('Tomorrow'));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('new-task-more')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('1 h'));
  await tester.tap(find.text('1 h'));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('new-task-save')));
  await settle(tester);
}

Future<Task> stored(TestApp app, WidgetTester tester, String title) async {
  final all = await tester.runAsync(app.repos.tasks.getAll);
  return all!.firstWhere((t) => t.title == title);
}

void main() {
  appTest('AC1/AC3: 1 h onto a 5.5 h day → dialog; Add anyway keeps the day', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await seed(app, tester, monday, 330);
    await addOneHourTomorrow(tester, 'Write report');

    expect(find.byKey(const ValueKey('overload-dialog')), findsOneWidget);
    expect(find.text('Monday is already full (6.5h of 6h)'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-load-chart')), findsOneWidget);
    expect(find.text('Move to Tue'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('overload-add-anyway')));
    await settle(tester);
    expect(find.byKey(const ValueKey('overload-dialog')), findsNothing);
    final t = await stored(app, tester, 'Write report');
    expect(localDue(t), monday);
  });

  appTest('AC3: Move saves on the suggested day', (tester, app) async {
    await useTallScreen(tester);
    await seed(app, tester, monday, 330);
    await addOneHourTomorrow(tester, 'Write report');

    await tester.tap(find.byKey(const ValueKey('overload-move')));
    await settle(tester);
    final t = await stored(app, tester, 'Write report');
    expect(localDue(t), DateTime(2026, 11, 10)); // Tuesday
    expect(t.durationMin, 60);
  });

  appTest('AC1: 1 h onto a 4 h day saves without a dialog', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await seed(app, tester, monday, 240);
    await addOneHourTomorrow(tester, 'Light day task');

    expect(find.byKey(const ValueKey('overload-dialog')), findsNothing);
    expect(localDue(await stored(app, tester, 'Light day task')), monday);
  });

  appTest('dismissing the dialog returns to the sheet without saving', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await seed(app, tester, monday, 330);
    await addOneHourTomorrow(tester, 'Maybe later');

    await tester.tapAt(const Offset(5, 5)); // outside the dialog
    await settle(tester);
    expect(find.byKey(const ValueKey('new-task-title')), findsOneWidget);
    final all = await tester.runAsync(app.repos.tasks.getAll);
    expect(all!.where((t) => t.title == 'Maybe later'), isEmpty);
  });

  appTest('AC5: Upcoming shows a 7-day heatmap; full days say so', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await seed(app, tester, monday, 420); // 117% → full
    await seed(app, tester, DateTime(2026, 11, 10), 180); // 50%
    await openTab(tester, 'Tasks');
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('load-heatmap')), findsOneWidget);
    for (var d = 8; d <= 14; d++) {
      expect(find.byKey(ValueKey('heat-$d')), findsOneWidget, reason: 'day $d');
    }
    expect(find.text('117%'), findsOneWidget);
    expect(find.text('⚠ Full'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('0%'), findsNWidgets(5));
  });
}
