// PBI-022 onboarding: first launch only (AC1), chips → active rules (AC2),
// forecast total (AC3), permissions in context (AC4), a short flow (AC5).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/onboarding/onboarding_screen.dart';

import '../../data/db_test_utils.dart';

import '../../fakes.dart';
import '../../widget_test_utils.dart';

final gateway = FakeGateway();
late CaptureFakes capture;

CaptureFakes makeCapture() {
  final tmp = Directory.systemTemp.createTempSync('lifeos_ob_');
  addTearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file open.
    }
  });
  return capture = CaptureFakes(Directory('${tmp.path}/vault')..createSync());
}

Future<void> addChip(
  WidgetTester tester,
  String key,
  String amount,
  int day,
) async {
  await tester.tap(find.byKey(ValueKey('ob-chip-$key')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('ob-amount')), amount);
  await tester.tap(find.byKey(const ValueKey('ob-day')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('ob-turn-on')));
  await settle(tester);
}

void main() {
  test('the role puts its likely payments first', () {
    expect(chipsFor(Role.parent).first.key, 'fee');
    expect(chipsFor(Role.student).take(2).map((c) => c.key), [
      'mobile',
      'internet',
    ]);
    expect(chipsFor(null).first.key, 'rent');
    expect(chipsFor(Role.parent), hasLength(payChips.length));
  });

  appTest(
    'AC1–AC5: role → skip scan → 2 chips → forecast → dashboard, once',
    (tester, app) async {
      await useTallScreen(tester);
      // AC1: first launch shows onboarding, not Home.
      expect(find.byKey(const ValueKey('ob-step-role')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-score')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ob-role-parent')));
      await tester.pumpAndSettle();

      // AC4: nothing asked yet.
      expect(capture.scanner.calls, 0);
      expect(gateway.permissionRequests, 0);
      await tester.tap(find.byKey(const ValueKey('ob-skip')));
      await tester.pumpAndSettle();
      expect(capture.scanner.calls, 0, reason: 'scan skipped: no camera');

      // AC2: the parent sees the school fee first; each chip → active rule.
      expect(find.byKey(const ValueKey('ob-chip-fee')), findsOneWidget);
      await addChip(tester, 'rent', '45000', 1);
      await addChip(tester, 'fee', '12000', 5);
      expect(find.byKey(const ValueKey('ob-on-rent')), findsOneWidget);
      expect(find.byKey(const ValueKey('ob-on-fee')), findsOneWidget);
      final rules = await tester.runAsync(app.repos.atcRules.getAll);
      expect(rules!.map((r) => (r.name, r.status, r.amountMinor)).toSet(), {
        ('Rent', 'active', 4500000),
        ('School fee', 'active', 1200000),
      });
      expect(gateway.permissionRequests, 0, reason: 'not before step 4');

      await tester.tap(find.byKey(const ValueKey('ob-next')));
      await settle(tester);
      // AC3: the forecast total = 45,000 + 12,000.
      expect(find.text('December fixed payments: Rs 57,000'), findsOneWidget);
      // AC4: the notification permission is asked here, in context.
      expect(gateway.permissionRequests, 1);

      await tester.tap(find.byKey(const ValueKey('ob-finish')));
      await settle(tester);
      expect(find.byKey(const ValueKey('home-score')), findsOneWidget);

      // AC1: never again, even when asked for directly.
      final done = await tester.runAsync(() => onboardingDone(app.db));
      expect(done, isTrue);
      await TestApp.restart(tester, app);
      await settle(tester);
      expect(find.byKey(const ValueKey('ob-step-role')), findsNothing);
      expect(find.byKey(const ValueKey('home-score')), findsOneWidget);
    },
    onboarded: false,
    gateway: gateway,
    capture: makeCapture,
  );

  appTest('the free plan stops at 3 chips and says so', (tester, app) async {
    await useTallScreen(tester);
    await tester.tap(find.byKey(const ValueKey('ob-role-justMe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ob-skip')));
    await tester.pumpAndSettle();
    await addChip(tester, 'rent', '45000', 1);
    await addChip(tester, 'internet', '3000', 10);
    await addChip(tester, 'mobile', '1500', 12);
    await addChip(tester, 'installment', '10000', 20);
    expect(find.byKey(const ValueKey('ob-limit')), findsOneWidget);
    final rules = await tester.runAsync(app.repos.atcRules.getAll);
    expect(rules, hasLength(3));
  }, onboarded: false);

  test(
    'upgrading installs with data skip onboarding; empty ones do not',
    () async {
      final db = memoryDb();
      addTearDown(db.close);
      final repos = await openLocalData(db);
      await skipOnboardingForExistingData(repos);
      expect(await onboardingDone(db), isFalse, reason: 'nothing yet');
      await repos.tasks.insert(TasksCompanion.insert(title: 'From Sprint 5'));
      await skipOnboardingForExistingData(repos);
      expect(await onboardingDone(db), isTrue);
    },
  );
}
