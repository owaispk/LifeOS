// PBI-033 AC5: the "Show details on widget" setting and the one-time
// prompt when App Lock is enabled.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/security/lock_gate.dart';

import '../../fakes.dart';
import '../../widget_test_utils.dart';

Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'More');
  await tester.tap(find.byKey(const ValueKey('more-settings')));
  await tester.pumpAndSettle();
}

void main() {
  appTest(
    'enabling App Lock prompts the widget privacy choice exactly once',
    (tester, app) async {
      await useTallScreen(tester);
      await openSettings(tester);

      // First enable: the prompt appears; keep showing details.
      await tester.tap(find.byKey(const ValueKey('set-app-lock')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('widget-details-prompt')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('widget-details-keep')));
      await settle(tester);
      var s = (await tester.runAsync(app.repos.userSettings.getAll))!.first;
      expect((s.appLock, s.widgetDetails), (true, true));

      // Off and on again: the choice was already offered — no prompt.
      await tester.tap(find.byKey(const ValueKey('set-app-lock')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('set-app-lock')));
      await settle(tester);
      expect(find.byKey(const ValueKey('widget-details-prompt')), findsNothing);

      // The switch itself still works both ways.
      await tester.tap(find.byKey(const ValueKey('set-widget-details')));
      await settle(tester);
      s = (await tester.runAsync(app.repos.userSettings.getAll))!.first;
      expect(s.widgetDetails, false);
    },
    extra: () => [
      authenticatorProvider.overrideWithValue(FakeAuthenticator()),
    ],
  );

  appTest(
    'choosing "Hide details" turns the setting off',
    (tester, app) async {
      await useTallScreen(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('set-app-lock')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('widget-details-hide')));
      await settle(tester);
      final s = (await tester.runAsync(app.repos.userSettings.getAll))!.first;
      expect((s.appLock, s.widgetDetails), (true, false));
    },
    extra: () => [
      authenticatorProvider.overrideWithValue(FakeAuthenticator()),
    ],
  );
}
