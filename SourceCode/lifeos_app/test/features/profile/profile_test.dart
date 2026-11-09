// PBI-035 My Profile: name and avatar on the shared Me-person, language,
// and the greeting style — neutral by default, cultural only by choice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../widget_test_utils.dart';

Finder homeTitle(String text) => find.descendant(
  of: find.byType(AppBar),
  matching: find.text(text),
);

/// Home → profile button → My Profile.
Future<void> openProfileFromHome(WidgetTester tester) async {
  await openTab(tester, 'Home');
  await tester.tap(find.byKey(const ValueKey('home-profile')));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String key) async {
  // ensureVisible, not scrollUntilVisible: text fields add scrollables.
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

void main() {
  appTest('More lists My Profile first; Home profile button opens it', (
    tester,
    app,
  ) async {
    await openTab(tester, 'More');
    expect(find.byKey(const ValueKey('more-profile')), findsOneWidget);
    expect(find.text('Your name, greeting and language'), findsOneWidget);
    final profileY = tester
        .getTopLeft(find.byKey(const ValueKey('more-profile')))
        .dy;
    final atcY = tester.getTopLeft(find.byKey(const ValueKey('more-atc'))).dy;
    expect(profileY, lessThan(atcY));

    await openProfileFromHome(tester);
    expect(find.byKey(const ValueKey('profile-list')), findsOneWidget);
    // The seeded placeholder "Me" shows as an empty name with a prompt.
    expect(find.text('What should we call you?'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-preview')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-preview')))
          .data,
      'Good morning ☀️',
    );
  });

  appTest('AC3: the name is the shared Me-person — one record, Home agrees', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openProfileFromHome(tester);
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Owais');
    await settle(tester);
    // Live preview on the profile screen itself.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-preview')))
          .data,
      'Good morning, Owais ☀️',
    );

    // One record: the Me-person, still 'self' and still the only one.
    final people = await tester.runAsync(() => app.repos.persons.getAll());
    final selves = people!.where((p) => p.relation == 'self').toList();
    expect(selves, hasLength(1));
    expect(selves.single.name, 'Owais');

    await openTab(tester, 'Home');
    expect(homeTitle('Good morning, Owais ☀️'), findsOneWidget);

    // Clearing the field never blanks the name — the last good one stays.
    await openProfileFromHome(tester);
    await tester.enterText(find.byKey(const ValueKey('profile-name')), '  ');
    await settle(tester);
    final after = await tester.runAsync(() => app.repos.persons.getAll());
    expect(after!.firstWhere((p) => p.relation == 'self').name, 'Owais');
  });

  appTest('AC3: the avatar shows on Home and in More', (tester, app) async {
    await useTallScreen(tester);
    await openProfileFromHome(tester);
    await tapVisible(tester, 'emoji-👩');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('profile-avatar'))).data,
      '👩',
    );
    await openTab(tester, 'Home');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-profile')),
        matching: find.text('👩'),
      ),
      findsOneWidget,
    );
  });

  appTest('AC2: greeting style — Salam by choice, custom word, and back', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openProfileFromHome(tester);
    await tapVisible(tester, 'set-greet-salam');
    await openTab(tester, 'Home');
    expect(homeTitle('Salam 👋'), findsOneWidget);

    // Custom: the user's own word. (The More branch keeps its route, so
    // switching back lands on My Profile directly.)
    await openTab(tester, 'More');
    await tapVisible(tester, 'set-greet-custom');
    await tester.enterText(
      find.byKey(const ValueKey('set-greet-custom-text')),
      'Shalom',
    );
    await settle(tester);
    await openTab(tester, 'Home');
    expect(homeTitle('Shalom 👋'), findsOneWidget);

    // Back to the neutral default (the test clock is 10:00 → morning).
    await openTab(tester, 'More');
    await tapVisible(tester, 'set-greet-auto');
    await openTab(tester, 'Home');
    expect(homeTitle('Good morning ☀️'), findsOneWidget);
  });

  appTest('language can be changed from My Profile too', (tester, app) async {
    await useTallScreen(tester);
    await openProfileFromHome(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-language')),
        matching: find.text('اردو'),
      ),
    );
    await settle(tester);
    expect(find.text('میری پروفائل'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-preview')))
          .data,
      'صبح بخیر ☀️',
    );
  });
}
