// PBI-029: the premium entitlement, the two free-tier limits, and the
// screen that sells and restores the subscription.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/premium/domain/limits.dart';
import 'package:lifeos_app/features/premium/platform/billing_source.dart';
import 'package:lifeos_app/features/premium/premium_providers.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../fakes.dart';
import '../capture/image_fixtures.dart';
import '../../widget_test_utils.dart';

final _now = testNow; // Sunday 8 Nov 2026, 10:00

late FakeBilling store;
late Directory _tmp;
late CaptureFakes fakes;

CaptureFakes makeFakes() {
  _tmp = Directory.systemTemp.createTempSync('lifeos_premium_');
  addTearDown(() {
    try {
      if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file open.
    }
  });
  fakes = CaptureFakes(Directory(p.join(_tmp.path, 'vault'))..createSync());
  return fakes;
}

List<Override> withStore() {
  store = FakeBilling();
  return [billingSourceProvider.overrideWithValue(store)];
}

Future<void> setPremium(
  TestApp app,
  WidgetTester tester, {
  required bool on,
}) => app.write(tester, () async {
  final row = (await app.repos.userSettings.getAll()).first;
  await app.repos.userSettings.update(
    row.id,
    UserSettingsCompanion(
      premiumUntil: Value(on ? trustedUntil(_now) : null),
      premiumCheckedAt: Value(_now.millisecondsSinceEpoch),
    ),
  );
});

/// Puts [n] documents straight into the Vault.
Future<void> seedDocuments(TestApp app, WidgetTester tester, int n) =>
    app.write(tester, () async {
      for (var i = 0; i < n; i++) {
        await app.repos.documents.insert(
          DocumentsCompanion.insert(title: 'Doc $i'),
        );
      }
    });

/// A small page image on disk.
String page(String name, {int seed = 1}) {
  final file = File(p.join(_tmp.path, name))
    ..writeAsBytesSync(
      img.encodeJpg(fakeDocument(seed: seed, width: 400, height: 500)),
    );
  return file.path;
}

/// OCR finishes before Save becomes tappable.
Future<void> tapSaveWhenReady(WidgetTester tester) async {
  await pumpUntilGone(tester, find.byKey(const ValueKey('review-reading')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('review-save')));
}

/// Taps Save and waits for the write to finish (a plain pumpAndSettle
/// spins on the saving indicator).
Future<void> saveAndWait(WidgetTester tester) async {
  await tapSaveWhenReady(tester);
  await tester.pump();
  await pumpUntilGone(tester, find.byType(CircularProgressIndicator));
  await tester.pumpAndSettle();
}

Future<List<Document>> docs(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.documents.getAll))!;

Future<UserSettingsRow> settingsRow(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.userSettings.getAll))!.first;

void main() {
  group('entitlement rules', () {
    test('premium holds until the cached trust runs out', () {
      expect(isPremiumAt(null, _now), isFalse, reason: 'never subscribed');
      expect(isPremiumAt(trustedUntil(_now), _now), isTrue);
      final expired = _now
          .subtract(entitlementTrust)
          .subtract(const Duration(days: 1));
      expect(isPremiumAt(trustedUntil(expired), _now), isFalse);
    });

    test('the store is asked at most once an hour, and always once', () {
      expect(dueForCheck(null, _now), isTrue, reason: 'never asked');
      final justNow = _now.millisecondsSinceEpoch;
      expect(dueForCheck(justNow, _now), isFalse);
      final anHourAgo = _now
          .subtract(entitlementRecheck)
          .millisecondsSinceEpoch;
      expect(dueForCheck(anHourAgo, _now), isTrue);
    });

    test('the test-phone store is off unless the build asks for it', () async {
      expect(testPremiumBuild, isFalse, reason: 'a normal build is real');
      const store = TestPremiumBilling();
      expect(await store.isAvailable(), isTrue);
      expect((await store.product())?.id, premiumProductId);
      expect(await store.subscribe(), isTrue);
      expect(await store.restore(), isTrue);
      expect(await store.isSubscribed(), isTrue);
      // No purchase token: managed AI must not think it has one.
      expect(await store.entitlementToken(), isNull);
    });
  });

  group('the document limit', () {
    test('free stops at the limit; premium never does (AC1, AC2)', () {
      expect(canSaveDocument(premium: false, liveDocuments: 24), isTrue);
      expect(canSaveDocument(premium: false, liveDocuments: 25), isFalse);
      expect(canSaveDocument(premium: true, liveDocuments: 25), isTrue);
      expect(canSaveDocument(premium: true, liveDocuments: 10000), isTrue);
    });

    test('someone already over the limit is not pushed under it (AC4)', () {
      // 30 documents on a free plan: adding is blocked, nothing else.
      expect(canSaveDocument(premium: false, liveDocuments: 30), isFalse);
      // And no scolding line either — the count is past warning.
      expect(
        documentsLeftToShow(premium: false, liveDocuments: 30),
        isNull,
      );
    });

    test('the "N left" line shows only near the wall (AC8)', () {
      expect(documentsLeftToShow(premium: false, liveDocuments: 19), isNull);
      expect(documentsLeftToShow(premium: false, liveDocuments: 20), 5);
      expect(documentsLeftToShow(premium: false, liveDocuments: 25), 0);
      expect(documentsLeftToShow(premium: true, liveDocuments: 20), isNull);
    });
  });

  group('the flow', () {
    appTest(
      'AC10: a free user who opens nothing makes no store call',
      (tester, app) async {
        await openTab(tester, 'Vault');
        await openTab(tester, 'Home');
        await settle(tester);
        expect(store.calls, 0);
      },
      extra: withStore,
    );

    appTest(
      'AC8: the Vault says how much room is left, near the limit',
      (tester, app) async {
        await seedDocuments(app, tester, 20);
        await openTab(tester, 'Vault');
        await settle(tester);
        expect(
          find.byKey(const ValueKey('vault-docs-left')),
          findsOneWidget,
        );
        expect(store.calls, 0, reason: 'a warning is not a store call');
      },
      extra: withStore,
    );

    appTest(
      'AC8: nothing is said while the user is well clear of the limit',
      (tester, app) async {
        await seedDocuments(app, tester, 5);
        await openTab(tester, 'Vault');
        await settle(tester);
        expect(find.byKey(const ValueKey('vault-docs-left')), findsNothing);
      },
      extra: withStore,
    );

    appTest(
      'AC2/AC8: a premium user is never counted or warned',
      (tester, app) async {
        await seedDocuments(app, tester, 40);
        await setPremium(app, tester, on: true);
        await openTab(tester, 'Vault');
        await settle(tester);
        expect(find.byKey(const ValueKey('vault-docs-left')), findsNothing);
      },
      extra: withStore,
    );

    appTest(
      'AC4: a library already over the limit is left whole',
      (tester, app) async {
        await seedDocuments(app, tester, 30);
        await openTab(tester, 'Vault');
        await settle(tester);
        // Every document is still there, on a free plan.
        expect(await docs(app, tester), hasLength(30));
        final row = await settingsRow(app, tester);
        expect(row.premiumUntil, isNull, reason: 'still free');
      },
      extra: withStore,
    );

    appTest(
      'AC3: one entitlement drives the whole app',
      (tester, app) async {
        await seedDocuments(app, tester, 30);
        await setPremium(app, tester, on: true);
        await openTab(tester, 'Vault');
        await settle(tester);
        // Vault: no warning. Settings: says Premium. No restart between.
        expect(find.byKey(const ValueKey('vault-docs-left')), findsNothing);
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-premium')),
          300,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('set-premium')));
        await tester.pumpAndSettle();
        expect(find.text("You're on Premium."), findsOneWidget);
      },
      extra: withStore,
    );

    appTest(
      'AC7: the Premium screen shows the store price and only real perks',
      (tester, app) async {
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-premium')),
          300,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('set-premium')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('set-premium')));
        await settle(tester);

        expect(find.byKey(const ValueKey('premium-list')), findsOneWidget);
        // The store's own formatted price, not one we built.
        expect(find.textContaining('Rs 450.00'), findsOneWidget);

        // Nothing unbuilt is advertised.
        for (final unbuilt in const [
          'backup',
          'Backup',
          'sync',
          'Sync',
          'AI',
          'family',
          'Family',
          'link',
          'Link',
        ]) {
          expect(
            find.textContaining(unbuilt),
            findsNothing,
            reason: '"$unbuilt" is not built yet and must not be sold',
          );
        }
      },
      extra: withStore,
    );

    appTest(
      'AC6: Restore brings Premium back without a second payment',
      (tester, app) async {
        store.owned = true; // bought on the old phone
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-premium')),
          300,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('set-premium')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('set-premium')));
        await settle(tester);

        await tester.tap(find.byKey(const ValueKey('premium-restore')));
        await settle(tester);

        expect(store.purchases, 0, reason: 'restoring is not buying');
        final row = await settingsRow(app, tester);
        expect(isPremiumAt(row.premiumUntil, _now), isTrue);
      },
      extra: withStore,
    );

    appTest(
      'subscribing turns Premium on',
      (tester, app) async {
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-premium')),
          300,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('set-premium')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('set-premium')));
        await settle(tester);

        await tester.tap(find.byKey(const ValueKey('premium-subscribe')));
        await settle(tester);

        expect(store.purchases, 1);
        final row = await settingsRow(app, tester);
        expect(isPremiumAt(row.premiumUntil, _now), isTrue);
        expect(find.text("You're on Premium."), findsOneWidget);
      },
      extra: withStore,
    );

    appTest(
      'AC5: an unreachable store never takes Premium away',
      (tester, app) async {
        await setPremium(app, tester, on: true);
        store
          ..owned = true
          ..reachable = null; // the store cannot be asked
        await openTab(tester, 'Vault');
        await settle(tester);

        final container = app;
        await tester.runAsync(() async {});
        // A refresh that cannot reach the store changes nothing.
        final before = (await settingsRow(container, tester)).premiumUntil;
        expect(before, isNotNull);
        await openTab(tester, 'Home');
        await settle(tester);
        final after = (await settingsRow(container, tester)).premiumUntil;
        expect(after, before, reason: 'no silent downgrade');
      },
      extra: withStore,
    );
  });

  group('the wall', () {
    appTest(
      'AC1: the 26th document is stopped, and the capture is kept',
      (tester, app) async {
        await seedDocuments(app, tester, freeTierDocumentLimit);
        await useTallScreen(tester);
        fakes.scanner.results.add([page('bill.jpg')]);
        await openTab(tester, 'Vault');
        await tester.tap(find.byKey(const ValueKey('vault-scan')));
        await pumpUntilFound(
          tester,
          find.byKey(const ValueKey('review-save')),
        );
        await tapSaveWhenReady(tester);
        await pumpUntilFound(
          tester,
          find.byKey(const ValueKey('upgrade-prompt')),
        );

        // Not now: nothing saved, and the capture is still on screen.
        await tester.tap(find.byKey(const ValueKey('upgrade-not-now')));
        await settle(tester);
        expect(await docs(app, tester), hasLength(freeTierDocumentLimit));
        expect(
          find.byKey(const ValueKey('review-save')),
          findsOneWidget,
          reason: 'the scan must not be thrown away',
        );
      },
      capture: makeFakes,
      extra: withStore,
    );

    appTest(
      'AC2: a premium user saves the 26th without a word',
      (tester, app) async {
        await seedDocuments(app, tester, freeTierDocumentLimit);
        await setPremium(app, tester, on: true);
        await useTallScreen(tester);
        fakes.scanner.results.add([page('bill.jpg')]);
        await openTab(tester, 'Vault');
        await tester.tap(find.byKey(const ValueKey('vault-scan')));
        await pumpUntilFound(
          tester,
          find.byKey(const ValueKey('review-save')),
        );
        await saveAndWait(tester);

        expect(find.byKey(const ValueKey('upgrade-prompt')), findsNothing);
        expect(
          await docs(app, tester),
          hasLength(freeTierDocumentLimit + 1),
        );
      },
      capture: makeFakes,
      extra: withStore,
    );
  });
}
