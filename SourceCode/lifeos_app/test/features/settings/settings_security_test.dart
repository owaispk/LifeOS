// PBI-025 Settings (language AC1, Classic AC4, export AC3, delete-all AC5)
// and PBI-024 locks (AC3 app lock, AC4 Vault lock, AC5 screenshots).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/security/crypto/vault_crypto.dart';
import 'package:lifeos_app/features/security/crypto/vault_files.dart';
import 'package:lifeos_app/features/security/lock_gate.dart';
import 'package:lifeos_app/features/settings/data/data_service.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../../fakes.dart';
import '../../widget_test_utils.dart';
import '../capture/image_fixtures.dart';

Future<void> setSettings(
  TestApp app,
  WidgetTester tester,
  UserSettingsCompanion c,
) => app.write(tester, () async {
  final row = (await app.repos.userSettings.getAll()).first;
  await app.repos.userSettings.update(row.id, c);
});

Future<void> openSettings(WidgetTester tester) async {
  await openTab(tester, 'More');
  await tester.tap(find.byKey(const ValueKey('more-settings')));
  await tester.pumpAndSettle();
}

void main() {
  appTest('AC1: Urdu switches strings and mirrors the layout, no restart', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await openSettings(tester);
    expect(find.text('Settings'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.byType(ListView).first)),
      TextDirection.ltr,
    );
    await tester.tap(find.text('اردو'));
    await settle(tester);
    expect(find.text('سیٹنگز'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(ListView).first)),
      TextDirection.rtl,
    );
    // And back.
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(find.text('Settings'), findsWidgets);
  });

  appTest('AC4: the Classic template raises text to at least 1.3×', (
    tester,
    app,
  ) async {
    await setSettings(
      app,
      tester,
      const UserSettingsCompanion(themeTemplate: Value('classic')),
    );
    final scale = MediaQuery.textScalerOf(
      tester.element(find.byType(Scaffold).first),
    ).scale(10);
    expect(scale, greaterThanOrEqualTo(13));
  });

  appTest('AC5: delete everything needs two confirmations, then onboarding', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await app.write(
      tester,
      () => app.repos.tasks.insert(TasksCompanion.insert(title: 'Secret')),
    );
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('set-delete-all')),
      300,
    );
    await tester.tap(find.byKey(const ValueKey('set-delete-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-all-continue')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('delete-all-confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('delete-all-field')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(confirm);
    await settle(tester);
    expect(find.byKey(const ValueKey('ob-step-role')), findsOneWidget);
    final tasks = await tester.runAsync(app.repos.tasks.getAll);
    expect(tasks, isEmpty);
    final folders = await tester.runAsync(app.repos.folders.getAll);
    expect(folders, isNotEmpty, reason: 'defaults seeded again');
  });

  group('locks', () {
    late FakeAuthenticator auth;

    appTest(
      'AC3: app lock asks on cold start; unlocking reveals the app',
      (tester, app) async {
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(appLock: Value(true)),
        );
        // Settings were written after the first frame: restart the app.
        await TestApp.restart(
          tester,
          app,
          extra: [authenticatorProvider.overrideWithValue(auth)],
        );
        await settle(tester);
        // The prompt was shown automatically and passed.
        expect(auth.asks, greaterThanOrEqualTo(1));
        expect(find.byKey(const ValueKey('app-lock')), findsNothing);
      },
      extra: () {
        auth = FakeAuthenticator();
        return [authenticatorProvider.overrideWithValue(auth)];
      },
    );

    appTest(
      'AC3: a failed check keeps the lock screen up',
      (tester, app) async {
        auth.pass = false;
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(appLock: Value(true)),
        );
        await TestApp.restart(
          tester,
          app,
          extra: [authenticatorProvider.overrideWithValue(auth)],
        );
        await settle(tester);
        expect(find.byKey(const ValueKey('app-lock')), findsOneWidget);
        auth.pass = true;
        await tester.tap(find.byKey(const ValueKey('unlock')));
        await settle(tester);
        expect(find.byKey(const ValueKey('app-lock')), findsNothing);
      },
      extra: () {
        auth = FakeAuthenticator();
        return [authenticatorProvider.overrideWithValue(auth)];
      },
    );

    appTest(
      'AC3: after N minutes in the background it locks again',
      (tester, app) async {
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(
            appLock: Value(true),
            autoLockMin: Value(5),
          ),
        );
        auth.pass = false;
        final binding = tester.binding;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        testClock = testClock.add(const Duration(minutes: 2));
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(tester);
        expect(
          find.byKey(const ValueKey('app-lock')),
          findsNothing,
          reason: '2 min < 5',
        );
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        testClock = testClock.add(const Duration(minutes: 6));
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(tester);
        expect(find.byKey(const ValueKey('app-lock')), findsOneWidget);
      },
      extra: () {
        auth = FakeAuthenticator();
        return [authenticatorProvider.overrideWithValue(auth)];
      },
    );

    appTest(
      'AC4: Vault lock asks again before showing the Vault',
      (tester, app) async {
        auth.pass = false;
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(vaultLock: Value(true)),
        );
        await openTab(tester, 'Vault');
        await settle(tester);
        expect(find.byKey(const ValueKey('vault-lock')), findsOneWidget);
        expect(find.byKey(const ValueKey('vault-home')), findsNothing);
        auth.pass = true;
        await tester.tap(find.byKey(const ValueKey('unlock')));
        await settle(tester);
        expect(find.byKey(const ValueKey('vault-home')), findsOneWidget);
      },
      extra: () {
        auth = FakeAuthenticator();
        return [authenticatorProvider.overrideWithValue(auth)];
      },
    );

    appTest(
      'locks never engage without a phone screen lock',
      (tester, app) async {
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(
            vaultLock: Value(true),
            appLock: Value(true),
          ),
        );
        await openTab(tester, 'Vault');
        await settle(tester);
        expect(find.byKey(const ValueKey('vault-home')), findsOneWidget);
        await openSettings(tester);
        final toggle = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('set-app-lock')),
        );
        expect(toggle.onChanged, isNull);
        expect(
          find.text('Set a screen lock on this phone to use this'),
          findsNWidgets(2),
        );
      },
      extra: () {
        auth = FakeAuthenticator(available: false);
        return [authenticatorProvider.overrideWithValue(auth)];
      },
    );
  });

  appTest('AC5: screenshots are blocked only while the Vault is visible', (
    tester,
    app,
  ) async {
    final calls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secureChannel,
      (call) async {
        calls.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        secureChannel,
        null,
      ),
    );
    await setSettings(
      app,
      tester,
      const UserSettingsCompanion(screenshotBlock: Value(true)),
    );
    await openTab(tester, 'Vault');
    await settle(tester);
    expect(calls.last, true);
    await openTab(tester, 'Home');
    await settle(tester);
    expect(calls.last, false);
  });

  group('export (real database)', () {
    test(
      'AC3: every live document (decrypted) and one CSV per table',
      () async {
        final db = memoryDb();
        addTearDown(db.close);
        await openLocalData(db);
        final repos = await Repositories.open(db);
        final tmp = await Directory.systemTemp.createTemp('lifeos_export_');
        addTearDown(() => tmp.delete(recursive: true));
        final crypto = VaultCrypto(MemoryKeyStore());
        final capture = CaptureService(
          repos,
          Directory(p.join(tmp.path, 'vault')),
          crypto: crypto,
        );
        String page(String n) => (File(
          p.join(tmp.path, n),
        )..writeAsBytesSync(jpeg(fakeDocument(width: 80, height: 100)))).path;
        final identity = (await repos.folders.getAll()).firstWhere(
          (f) => f.kind == 'identity',
        );
        await capture.save(
          CaptureDraft.scan([page('a.jpg')]),
          FilingDetails(title: 'Passport', folderId: identity.id),
        );
        await capture.save(
          CaptureDraft.scan([page('b.jpg'), page('c.jpg')]),
          const FilingDetails(title: 'Lease', format: OutputFormat.jpeg),
        );
        final gone = await capture.save(
          CaptureDraft.scan([page('d.jpg')]),
          const FilingDetails(title: 'Old bill'),
        );
        await repos.documents.softDelete(gone.id);

        final service = DataService(
          repos,
          VaultFiles(repos, crypto),
          MemoryKeyStore(),
          null,
        );
        final result = await service.export();
        expect(result.documentCount, 2);
        final zip = ZipDecoder().decodeBytes(result.zip);
        final names = zip.files.map((f) => f.name).toSet();
        expect(names.where((n) => n.startsWith('documents/')).toSet(), {
          'documents/Identity/Passport.pdf',
          'documents/Unfiled/Lease p1.jpg',
          'documents/Unfiled/Lease p2.jpg',
        });
        final passport = zip.findFile('documents/Identity/Passport.pdf')!;
        expect(
          utf8.decode(passport.content.sublist(0, 4)),
          '%PDF',
          reason: 'decrypted',
        );
        for (final t in [
          'tasks',
          'documents',
          'payments',
          'expenses',
          'atc_rules',
          'persons',
          'folders',
          'categories',
          'user_settings',
          'document_files',
        ]) {
          expect(names, contains('data/$t.csv'));
        }
        final docsCsv = utf8.decode(
          zip.findFile('data/documents.csv')!.content,
        );
        expect(docsCsv, contains('Passport'));
        expect(
          docsCsv,
          isNot(contains('Old bill')),
          reason: 'deleted excluded',
        );
        expect(names, contains('data/export.json'));
      },
    );
  });
}
