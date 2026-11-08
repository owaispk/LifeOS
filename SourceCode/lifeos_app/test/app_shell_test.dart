// PBI-001 acceptance tests: app shell, navigation, FAB, accessibility.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/features/tasks/tasks_screen.dart';
import 'package:lifeos_app/shared/widgets/empty_state.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: LifeOsApp()));
  await tester.pumpAndSettle();
}

Finder appBarTitle(String title) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );

Finder navItem(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  const tabs = ['Home', 'Tasks', 'Vault', 'Money', 'More'];

  testWidgets('AC1: opens on the Home tab', (tester) async {
    await pumpApp(tester);
    expect(appBarTitle('Home'), findsOneWidget);
  });

  testWidgets('AC2/AC7: every tab opens its screen with an empty state',
      (tester) async {
    await pumpApp(tester);
    for (final tab in tabs) {
      await tester.tap(navItem(tab));
      await tester.pumpAndSettle();
      expect(appBarTitle(tab), findsOneWidget, reason: '$tab app bar');
      expect(find.byType(EmptyState), findsOneWidget, reason: '$tab body');
    }
  });

  testWidgets('AC2: tab state is preserved when switching tabs',
      (tester) async {
    await pumpApp(tester);
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

  testWidgets('AC3: FAB expands 4 actions and each opens a sheet',
      (tester) async {
    await pumpApp(tester);
    for (final action in ['task', 'scan', 'voice', 'expense']) {
      await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
      await tester.pumpAndSettle();
      for (final a in ['task', 'scan', 'voice', 'expense']) {
        expect(find.byKey(ValueKey('quick-action-$a')), findsOneWidget);
      }

      await tester.tap(find.byKey(ValueKey('quick-action-$action')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('quick-action-sheet-$action')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('quick-action-task')), findsNothing,
          reason: 'menu collapses once an action is chosen');

      // Dismiss the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('AC3: tapping outside collapses the FAB menu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsOneWidget);

    await tester.tapAt(const Offset(20, 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsNothing);
    expect(find.byKey(const ValueKey('quick-action-scan')), findsNothing);
  });

  testWidgets('AC3: switching tabs collapses the FAB menu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(navItem('Vault'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fab-barrier')), findsNothing);
    expect(appBarTitle('Vault'), findsOneWidget);
  });

  testWidgets('AC5: tap targets are ≥ 48dp and labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('AC4: theme follows the system brightness', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
