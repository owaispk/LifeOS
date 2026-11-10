// PBI-030 diagnostics log: capture (AC1), retention (AC2), privacy (AC3),
// never throws (AC6). The Diagnostics screen (AC4, AC5) is tested below.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/log/app_log.dart';
import 'package:lifeos_app/core/log/diagnostics.dart';
import 'package:lifeos_app/features/settings/diagnostics_screen.dart';

import '../widget_test_utils.dart';

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('lifeos_log_');
  });
  tearDown(() {
    AppLog.reset();
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file
    }
  });

  group('scrubber (AC3)', () {
    test('masks numbers, CNIC, phones, emails and amounts', () {
      expect(scrubLogText('CNIC 42101-1234567-1 saved'), 'CNIC <number> saved');
      expect(scrubLogText('call 0300 1234567 now'), 'call <number> now');
      expect(scrubLogText('ref 08 11111 2233445 U'), 'ref <number> U');
      expect(scrubLogText('mail ali@example.com'), 'mail <email>');
      expect(scrubLogText('paid Rs 12,000 today'), 'paid <amount> today');
      expect(scrubLogText('PKR 4500'), '<amount>');
      expect(scrubLogText('Account 0400012345678'), 'Account <number>');
    });

    test('keeps short numbers, versions and ordinary words', () {
      expect(scrubLogText('scheduled 12'), 'scheduled 12');
      expect(scrubLogText('upgrade v5 → v6'), 'upgrade v5 → v6');
      expect(scrubLogText('saved bill · 2 file(s)'), 'saved bill · 2 file(s)');
    });
  });

  group('file log', () {
    test('writes JSON lines; reads newest first', () async {
      final log = await AppLog.init(tmp);
      AppLog.i('app', 'start');
      AppLog.w('ocr', 'low confidence');
      AppLog.e('capture', StateError('boom'), StackTrace.current);
      await log.flush();
      final entries = await log.read();
      expect(entries.map((e) => e.level), [
        LogLevel.error,
        LogLevel.warning,
        LogLevel.info,
      ]);
      expect(entries.first.message, contains('boom'));
      expect(entries.first.stack, isNotNull);
      final file = (await log.files()).single;
      final first = jsonDecode(file.readAsLinesSync().first) as Map;
      expect(first['l'], 'info');
    });

    test('messages and stacks are scrubbed before writing (AC3)', () async {
      final log = await AppLog.init(tmp);
      AppLog.e('x', 'failed for 42101-1234567-1 / Rs 5,000');
      await log.flush();
      final raw = (await log.files()).single.readAsStringSync();
      expect(raw, isNot(contains('1234567')));
      expect(raw, isNot(contains('5,000')));
    });

    test('AC2: files older than 7 days are deleted on start', () async {
      final now = DateTime(2026, 11, 9);
      final log = await AppLog.init(tmp, now: now);
      for (var d = 0; d < 10; d++) {
        log.fileFor(DateTime(2026, 11, 9 - d)).writeAsStringSync('{}\n');
      }
      await AppLog.init(tmp, now: now);
      final names = (await AppLog.instance.files())
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names, hasLength(7));
      expect(names.first, 'lifeos-2026-11-09.log');
      expect(names.last, 'lifeos-2026-11-03.log');
    });

    test('AC2: a day\'s file never grows past 1 MB', () async {
      final log = await AppLog.init(tmp);
      final big = 'x' * 2000;
      for (var i = 0; i < 700; i++) {
        AppLog.i('load', big);
        if (i % 100 == 0) await log.flush();
      }
      await log.flush();
      final f = (await log.files()).single;
      expect(f.lengthSync(), lessThanOrEqualTo(AppLog.maxFileBytes));
      expect(f.lengthSync(), greaterThan(AppLog.maxFileBytes - 5000));
    });

    test('AC6: logging never throws, even if the folder disappears', () async {
      final log = await AppLog.init(tmp);
      tmp.deleteSync(recursive: true);
      expect(() => AppLog.e('x', 'still fine'), returnsNormally);
      await expectLater(log.flush(), completes);
      expect(log.recent.last.message, 'still fine');
      tmp.createSync();
    });

    test('Clear removes every entry and file', () async {
      final log = await AppLog.init(tmp);
      AppLog.e('x', 'one');
      await log.flush();
      await log.clear();
      expect(await log.files(), isEmpty);
      expect(await log.read(), isEmpty);
    });
  });

  test('AC3: no log call passes titles, text, amounts or names', () {
    final call = RegExp(r'AppLog\.[iwe]\(([^;]*)\);', dotAll: true);
    final banned = RegExp(
      r'\.(title|ocrText|amountMinor|name|notes|refNumber|issuer|'
      r'number|value|body)\b',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in call.allMatches(src)) {
        if (banned.hasMatch(m[1]!)) offenders.add('${f.path}: ${m[0]}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('AC1: uncaught Flutter and async errors are logged with route', (
    tester,
  ) async {
    AppLog.reset();
    final previousFlutter = FlutterError.onError;
    final previousPlatform = WidgetsBinding.instance.platformDispatcher.onError;
    // The test framework's own handler would fail this test; captureErrors
    // calls the previous handler, so stand in a quiet one first.
    FlutterError.onError = (_) {};
    captureErrors();
    addTearDown(() {
      FlutterError.onError = previousFlutter;
      WidgetsBinding.instance.platformDispatcher.onError = previousPlatform;
    });
    AppLog.currentRoute = '/vault';
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('layout broke'),
        stack: StackTrace.current,
      ),
    );
    final handled = WidgetsBinding.instance.platformDispatcher.onError!(
      StateError('async broke'),
      StackTrace.current,
    );
    expect(handled, isTrue);
    final errors = AppLog.instance.recent
        .where((e) => e.level == LogLevel.error)
        .toList();
    expect(errors.map((e) => e.area), ['flutter', 'uncaught']);
    expect(errors.every((e) => e.route == '/vault'), isTrue);
    expect(errors.every((e) => e.stack != null), isTrue);
    AppLog.currentRoute = null;
  });

  group('Diagnostics screen', () {
    late List<List<int>> shared;

    appTest(
      'AC4/AC5: entries newest first, errors filter, share ZIP, clear',
      (tester, app) async {
        await useTallScreen(tester);
        AppLog.reset();
        AppLog.i('app', 'start');
        AppLog.e('capture', 'save failed: StateError');
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-diagnostics')),
          300,
        );
        // scrollUntilVisible stops as soon as the row is built, which
        // can still leave it below the fold on a longer list.
        await tester.ensureVisible(
          find.byKey(const ValueKey('set-diagnostics')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('set-diagnostics')));
        await settle(tester);

        // Navigation lines are logged too, so only the error count is fixed.
        expect(find.textContaining('· 1 error'), findsOneWidget);
        final titles = tester
            .widgetList<ExpansionTile>(find.byType(ExpansionTile))
            .map((t) => (t.title as Text).data)
            .toList();
        // "nav" lines may be there too: the error is listed above "start".
        expect(
          titles.indexOf('save failed: StateError'),
          lessThan(titles.indexOf('start')),
        );

        await tester.tap(find.byKey(const ValueKey('diag-errors-only')));
        await tester.pumpAndSettle();
        expect(find.text('start'), findsNothing);
        expect(find.text('save failed: StateError'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('diag-share')));
        await settle(tester);
        final zip = ZipDecoder().decodeBytes(shared.single);
        final names = zip.files.map((f) => f.name).toSet();
        expect(names, contains('device.txt'));
        expect(names, contains('lifeos-memory.log'));

        await tester.tap(find.byKey(const ValueKey('diag-clear')));
        await settle(tester);
        expect(find.text('Nothing logged yet'), findsOneWidget);
        expect(AppLog.instance.recent, isEmpty);
      },
      extra: () {
        shared = [];
        return [
          shareLogsProvider.overrideWithValue((zip) async => shared.add(zip)),
          deviceFactsProvider.overrideWith((ref) async => {'app': 'LifeOS'}),
        ];
      },
    );

    appTest(
      'a test error appears at the top',
      (tester, app) async {
        await useTallScreen(tester);
        AppLog.reset();
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-diagnostics')),
          300,
        );
        // scrollUntilVisible stops as soon as the row is built, which
        // can still leave it below the fold on a longer list.
        await tester.ensureVisible(
          find.byKey(const ValueKey('set-diagnostics')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('set-diagnostics')));
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('diag-test-error')));
        await settle(tester);
        expect(
          find.textContaining('Test error recorded from Diagnostics'),
          findsOneWidget,
        );
      },
      extra: () => [
        deviceFactsProvider.overrideWith((ref) async => {'app': 'LifeOS'}),
      ],
    );
  });
}
