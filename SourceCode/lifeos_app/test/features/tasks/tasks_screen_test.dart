// PBI-009 widget tests: Today / Upcoming / Domains, add, complete + undo,
// snooze, ATC source line, detail, empty states.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/tasks/ui/task_detail_screen.dart';

import '../../widget_test_utils.dart';

/// The Task Detail screen's own list (other Scrollables exist offstage).
final detailScrollable = find
    .descendant(
      of: find.byType(TaskDetailScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Finder taskTitle(String title) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(title));

Future<Task> addTask(
  TestApp app,
  WidgetTester tester,
  String title, {
  DateTime? due,
  bool allDay = true,
  int priority = 1,
  String? atcRuleId,
  String? sourceDocumentId,
  String? repeatRule,
}) {
  return app.write(
    tester,
    () => app.repos.tasks.insert(
      TasksCompanion.insert(
        title: title,
        dueAt: Value(due?.millisecondsSinceEpoch),
        allDay: Value(allDay),
        priority: Value(priority),
        atcRuleId: Value(atcRuleId),
        sourceDocumentId: Value(sourceDocumentId),
        repeatRule: Value(repeatRule),
      ),
    ),
  );
}

void main() {
  appTest('AC8: empty Today shows an empty state with Add task', (
    tester,
    app,
  ) async {
    await openTab(tester, 'Tasks');
    expect(find.text('Nothing on your plate'), findsOneWidget);
    expect(find.text('➕ Add task'), findsOneWidget);

    for (final view in ['Upcoming', 'Domains']) {
      await tester.tap(find.text(view));
      await tester.pumpAndSettle();
      expect(find.text('➕ Add task'), findsOneWidget, reason: view);
    }
  });

  appTest('AC1: a title-only task appears under Anytime', (tester, app) async {
    await openTab(tester, 'Tasks');

    await tester.tap(find.text('➕ Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-task-title')),
      'Review CV',
    );
    await tester.pump(); // let the Add button enable
    await tester.tap(find.byKey(const ValueKey('new-task-save')));
    await settle(tester);

    expect(find.byKey(const ValueKey('section-anytime')), findsOneWidget);
    expect(taskTitle('Review CV'), findsOneWidget);
  });

  appTest('the FAB Task action opens the New Task sheet', (tester, app) async {
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-action-task')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-task-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-task-save')), findsOneWidget);
  });

  appTest('AC2: Today renders sections in spec order', (tester, app) async {
    await addTask(app, tester, 'Anytime task');
    await addTask(
      app,
      tester,
      'Call electrician',
      due: DateTime(2026, 11, 8, 16),
      allDay: false,
    );
    await addTask(app, tester, 'Renew licence', due: DateTime(2026, 11, 6));
    await openTab(tester, 'Tasks');

    final order = ['overdue', 'timed', 'anytime']
        .map((s) => tester.getTopLeft(find.byKey(ValueKey('section-$s'))).dy)
        .toList();
    expect(order, orderedEquals([...order]..sort()));
    expect(find.text('4:00 PM'), findsOneWidget);
  });

  appTest('AC3: completing removes the task; Undo brings it back', (
    tester,
    app,
  ) async {
    final t = await addTask(app, tester, 'Call electrician');
    await openTab(tester, 'Tasks');
    expect(taskTitle('Call electrician'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('complete-${t.id}')));
    await tester.pump(const Duration(milliseconds: 300)); // tick animation
    await settle(tester);
    expect(taskTitle('Call electrician'), findsNothing);
    expect(find.byKey(const ValueKey('undo-snackbar')), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(taskTitle('Call electrician'), findsOneWidget);

    // Let the snackbar's 5 s timer finish.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  appTest('AC3: swipe right completes', (tester, app) async {
    await addTask(app, tester, 'Swipe me');
    await openTab(tester, 'Tasks');

    await tester.fling(taskTitle('Swipe me'), const Offset(500, 0), 2000);
    await settle(tester);
    expect(taskTitle('Swipe me'), findsNothing);
    final stored = (await tester.runAsync(app.repos.tasks.getAll))!;
    expect(stored.single.status, 'done');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  appTest('AC4: completing a repeating task shows the next one', (
    tester,
    app,
  ) async {
    final t = await addTask(
      app,
      tester,
      'Water plants',
      due: DateTime(2026, 11, 8),
      repeatRule: 'FREQ=DAILY',
    );
    await openTab(tester, 'Tasks');

    await tester.tap(find.byKey(ValueKey('complete-${t.id}')));
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Done — next one scheduled'), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(taskTitle('Water plants'), findsOneWidget);
    expect(find.textContaining('TOMORROW'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  appTest('AC5/AC6: swipe left → Tomorrow moves it to Upcoming', (
    tester,
    app,
  ) async {
    await addTask(app, tester, 'Email landlord');
    await addTask(app, tester, 'In three days', due: DateTime(2026, 11, 11));
    await openTab(tester, 'Tasks');

    await tester.fling(
      taskTitle('Email landlord'),
      const Offset(-500, 0),
      2000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('snooze-tomorrow')));
    await settle(tester);
    expect(taskTitle('Email landlord'), findsNothing);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(taskTitle('Email landlord'), findsOneWidget);
    expect(
      find.text('9:00 AM').evaluate().isNotEmpty ||
          find.text('Tomorrow, 9:00 AM').evaluate().isNotEmpty,
      isTrue,
    );
    // Two days with tasks → two headers; the empty days in between are hidden.
    expect(find.textContaining('TOMORROW'), findsOneWidget);
    expect(find.textContaining('WED, 11 NOV'), findsOneWidget);
    expect(find.textContaining('TUE, 10 NOV'), findsNothing);
  });

  appTest('AC7: ATC tasks show ⚡ and their source opens the document', (
    tester,
    app,
  ) async {
    final doc = await app.write(
      tester,
      () => app.repos.documents.insert(
        DocumentsCompanion.insert(
          title: 'K-Electric Bill — Oct 2026',
          docType: const Value('bill'),
          issuer: const Value('K-Electric'),
        ),
      ),
    );
    final rule = await app.write(
      tester,
      () => app.repos.atcRules.insert(
        AtcRulesCompanion.insert(
          kind: 'bill_pattern',
          name: 'Electricity — K-Electric',
          status: const Value('active'), // not a pending M1 proposal
        ),
      ),
    );
    await addTask(
      app,
      tester,
      'Pay electricity bill',
      due: DateTime(2026, 11, 8),
      atcRuleId: rule.id,
      sourceDocumentId: doc.id,
    );
    await openTab(tester, 'Tasks');

    expect(find.byKey(const ValueKey('section-payments')), findsOneWidget);
    expect(find.byKey(const ValueKey('atc-chip')), findsOneWidget);

    await tester.tap(taskTitle('Pay electricity bill'));
    await tester.pumpAndSettle();
    expect(
      find.text('Created from: K-Electric Bill — Oct 2026'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('detail-skip')),
      200,
      scrollable: detailScrollable,
    );
    expect(find.byKey(const ValueKey('detail-skip')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-mute')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('detail-source')),
      -200,
      scrollable: detailScrollable,
    );
    await tester.tap(find.byKey(const ValueKey('detail-source')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('document-summary')), findsOneWidget);
    expect(find.text('Issuer: K-Electric'), findsOneWidget);
  });

  appTest('detail: edit priority, add sub-task, delete', (tester, app) async {
    final t = await addTask(app, tester, 'Plan trip');
    await openTab(tester, 'Tasks');
    await tester.tap(taskTitle('Plan trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('High'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('detail-add-subtask')),
      200,
      scrollable: detailScrollable,
    );
    await tester.enterText(
      find.byKey(const ValueKey('detail-add-subtask')),
      'Book hotel',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Book hotel'), findsOneWidget);
    expect(find.text('Sub-tasks (0/1)'), findsOneWidget);

    final stored = await tester.runAsync(() => app.repos.tasks.getById(t.id));
    expect(stored!.priority, 2);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('detail-delete')),
      200,
      scrollable: detailScrollable,
    );
    await tester.tap(find.byKey(const ValueKey('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await settle(tester);
    expect(find.text('Nothing on your plate'), findsOneWidget);
    expect(await tester.runAsync(() => app.repos.tasks.getById(t.id)), isNull);
  });
}
