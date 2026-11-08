// PBI-012 widget test: Task Detail → Reminders (add, permission in
// context, remove).
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../../fakes.dart';
import '../../widget_test_utils.dart';

void main() {
  final gateway = FakeGateway();

  appTest('add "1 hour before", permission asked in context, then remove', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final t = await app.write(
      tester,
      () => app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Dentist',
          allDay: const Value(false),
          dueAt: Value(DateTime(2026, 11, 9, 15).millisecondsSinceEpoch),
        ),
      ),
    );
    await openTab(tester, 'Tasks');
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dentist'));
    await tester.pumpAndSettle();
    expect(gateway.permissionRequests, 0);

    await tester.tap(find.byKey(const ValueKey('add-reminder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-offset-hour1')));
    await settle(tester);

    expect(find.text('Tomorrow, 2:00 PM'), findsOneWidget);
    expect(gateway.permissionRequests, 1);
    final stored = await tester.runAsync(
      () => app.repos.taskReminders.getWhere((r) => r.taskId.equals(t.id)),
    );
    expect(
      DateTime.fromMillisecondsSinceEpoch(stored!.single.fireAt),
      DateTime(2026, 11, 9, 14),
    );

    await tester.tap(find.byTooltip('Remove reminder'));
    await settle(tester);
    expect(find.text('Tomorrow, 2:00 PM'), findsNothing);
  }, gateway: gateway);
}
