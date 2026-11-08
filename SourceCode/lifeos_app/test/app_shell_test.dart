// PBI-001 acceptance tests: app shell, navigation, FAB, accessibility.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/tasks/tasks_screen.dart';
import 'package:lifeos_app/shared/widgets/empty_state.dart';

import 'widget_test_utils.dart';

Finder appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

void main() {
  const tabs = ['Home', 'Tasks', 'Vault', 'Money', 'More'];

  appTest('AC1: opens on the Home tab', (tester, app) async {
    expect(appBarTitle('Home'), findsOneWidget);
  });

  appTest('AC2/AC7: every tab opens its screen with an empty state', (
    tester,
    app,
  ) async {
    for (final tab in tabs) {
      await tester.tap(navItem(tab));
      await tester.pumpAndSettle();
      expect(appBarTitle(tab), findsOneWidget, reason: '$tab app bar');
      // Every tab shows content or an empty state — never a blank screen.
      // (The Vault has folders since PBI-005; More is a menu since PBI-017.)
      expect(
        switch (tab) {
          'Vault' => find.byKey(const ValueKey('vault-home')),
          'More' => find.byKey(const ValueKey('more-menu')), // PBI-017
          _ => find.byType(EmptyState),
        },
        findsOneWidget,
        reason: '$tab body',
      );
    }
  });

  appTest('AC2: tab state is preserved when switching tabs', (
    tester,
    app,
  ) async {
    await tester.tap(navItem('Tasks'));
    await tester.pumpAndSettle();
    final tasksElement = tester.element(find.byType(TasksScreen));

    await tester.tap(navItem('Home'));
    await tester.pumpAndSettle();
    // Still mounted (offstage) — same element, not rebuilt from scratch.
    expect(find.byType(TasksScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(navItem('Tasks'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(TasksScreen)), same(tasksElement));
  });

  appTest('AC3: FAB expands 4 actions and each opens a sheet', (
    tester,
    app,
  ) async {
    for (final action in ['task', 'scan', 'voice', 'expense']) {
      await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
      await tester.pumpAndSettle();
      for (final a in ['task', 'scan', 'voice', 'expense']) {
        expect(find.byKey(ValueKey('quick-action-$a')), findsOneWidget);
      }

      await tester.tap(find.byKey(ValueKey('quick-action-$action')));
      await tester.pumpAndSettle();
      // Task and Expense open their real sheets (PBI-009, PBI-018); Scan
      // opens the device scanner (PBI-003 — none in tests, so nothing
      // opens); Voice is still a placeholder (PBI-010).
      final opened = switch (action) {
        'task' => 'new-task-title',
        'expense' => 'expense-amount',
        'voice' => 'quick-action-sheet-voice',
        _ => null,
      };
      if (opened != null) {
        expect(find.byKey(ValueKey(opened)), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('quick-action-task')),
        findsNothing,
        reason: 'menu collapses once an action is chosen',
      );

      // Dismiss the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }
  });

  appTest('AC3: tapping outside collapses the FAB menu', (tester, app) async {
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsOneWidget);

    await tester.tapAt(const Offset(20, 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsNothing);
    expect(find.byKey(const ValueKey('quick-action-scan')), findsNothing);
  });

  appTest('AC3: switching tabs collapses the FAB menu', (tester, app) async {
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(navItem('Vault'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsNothing);
    expect(appBarTitle('Vault'), findsOneWidget);
  });

  appTest('AC5: tap targets are ≥ 48dp and labelled', (tester, app) async {
    final handle = tester.ensureSemantics();
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  appTest('AC4: theme follows the system brightness', (tester, app) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
