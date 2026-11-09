// PBI-035 My Profile: name and avatar on the shared Me-person, language,
// and the greeting style — neutral by default, cultural only by choice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/shared/format.dart';

import '../../widget_test_utils.dart';
import '../home/home_test.dart' show addPayment;

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

  appTest('AC4/AC5: symbol and week start change Home\'s week, live', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    // The test clock is Sunday 8 Nov.
    await addPayment(app, tester, 'Rent', '2026-11-03', amount: 1000000);
    await addPayment(app, tester, 'Internet', '2026-11-07', amount: 450000);
    await addPayment(app, tester, 'Fee', '2026-11-12', amount: 900000);
    await settle(tester);
    // Phone defaults (en-PK): Rs, Monday weeks → 2–8 Nov.
    expect(find.text('Rs 14,500 in payments this week'), findsOneWidget);

    await openProfileFromHome(tester);
    await tapVisible(tester, 'profile-currency-₹');
    await tester.ensureVisible(find.byKey(const ValueKey('profile-week-start')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-week-start')),
        matching: find.text('Sun'),
      ),
    );
    await settle(tester);

    // Sunday weeks → 8–14 Nov: only the fee, in the new symbol.
    await openTab(tester, 'Home');
    expect(find.text('₹ 9,000 in payments this week'), findsOneWidget);

    // Back to Auto restores the phone's defaults.
    await openTab(tester, 'More');
    await tapVisible(tester, 'profile-currency-auto');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-week-start')),
        matching: find.text('Auto'),
      ),
    );
    await settle(tester);
    await openTab(tester, 'Home');
    expect(find.text('Rs 14,500 in payments this week'), findsOneWidget);
  });

  appTest('AC5: the date-order choice reaches the date helpers', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openProfileFromHome(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('profile-date-order')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('profile-date-order')),
        matching: find.text('Nov 9'),
      ),
    );
    await settle(tester);
    expect(dayMonth(DateTime(2026, 11, 9)), 'Nov 9');
    expect(formatDay(DateTime(2026, 11, 20)), 'Fri, Nov 20');
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
