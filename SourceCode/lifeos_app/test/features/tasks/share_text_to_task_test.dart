// PBI-034: text shared from another app becomes a ready-made task.
//
// The pure-Dart half (amount parsing, the title and notes a shared
// message yields, mixed-share arbitration) plus the widget flow: the
// sheet opens pre-filled, nothing is created until Add, and App Lock
// comes first.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/capture/capture_providers.dart';
import 'package:lifeos_app/features/capture/platform/capture_platform.dart';
import 'package:lifeos_app/features/security/lock_gate.dart';
import 'package:lifeos_app/features/tasks/domain/nl_parser.dart';
import 'package:lifeos_app/features/tasks/domain/task_title.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../fakes.dart';
import '../../widget_test_utils.dart';

final _now = DateTime(2026, 11, 8, 10); // Sunday

late Directory _tmp;
late CaptureFakes fakes;

CaptureFakes makeFakes() {
  _tmp = Directory.systemTemp.createTempSync('lifeos_share_text_');
  addTearDown(() {
    try {
      if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may still hold a file open; the OS temp cleaner wins.
    }
  });
  fakes = CaptureFakes(Directory(p.join(_tmp.path, 'vault'))..createSync());
  return fakes;
}

final titleField = find.byKey(const ValueKey('new-task-title'));

String titleText(WidgetTester tester) =>
    tester.widget<TextField>(titleField).controller!.text;

Future<void> setSettings(
  TestApp app,
  WidgetTester tester,
  UserSettingsCompanion c,
) => app.write(tester, () async {
  final row = (await app.repos.userSettings.getAll()).first;
  await app.repos.userSettings.update(row.id, c);
});

Future<List<Task>> tasks(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(app.repos.tasks.getAll))!;

void main() {
  group('amount (AC1)', () {
    test('"Rs 4,520" is read, chipped and taken out of the title', () {
      final p = parseTask('Electricity bill Rs 4,520 due 15 Nov', _now);
      expect(p.amount, 'Rs 4,520');
      expect(p.matched[ParsedPart.amount], 'Rs 4,520');
      expect(p.date, DateTime(2026, 11, 15));
      expect(p.domain, 'money');
      expect(p.title, 'Electricity bill');
    });

    test('PKR, ₨ and a trailing /- all count, and mean money', () {
      expect(parseTask('fees PKR 12000 tomorrow', _now).amount, 'PKR 12000');
      expect(parseTask('x ₨ 900', _now).amount, '₨ 900');
      expect(parseTask('rent Rs 45,000/- on 5th', _now).amount, 'Rs 45,000/-');
      // "PKR" carries no hint word of its own, so the amount is the signal.
      expect(parseTask('send PKR 500', _now).domain, 'money');
    });

    test('text with no amount is untouched (AC7)', () {
      final p = parseTask('pay electricity bill friday 5pm', _now);
      expect(p.amount, isNull);
      expect(p.matched.containsKey(ParsedPart.amount), isFalse);
      expect(p.title, 'Pay electricity bill');
    });

    test('a bare number is not an amount', () {
      expect(parseTask('buy 6 eggs tomorrow', _now).amount, isNull);
      expect(parseTask('call at 5', _now).amount, isNull);
    });

    test('dropping the chip puts the amount back in the title', () {
      final p = parseTask('Electricity bill Rs 4,520', _now);
      expect(p.without(ParsedPart.amount).amount, isNull);
      expect(
        titleFrom(
          'Electricity bill Rs 4,520',
          matchedWords(p, dropped: {ParsedPart.amount}),
        ),
        'Electricity bill Rs 4,520',
      );
    });
  });

  group('shared text title and notes (AC3)', () {
    test('a forwarded message titles from its first line', () {
      const text =
          'Reminder from school\n'
          'Fee voucher Rs 12,000 due 20 Nov\n'
          'Please pay at any branch before closing.';
      final parsed = parseTask(text, _now);
      expect(parsed.date, DateTime(2026, 11, 20), reason: 'date mid-text');
      expect(parsed.amount, 'Rs 12,000');
      expect(sharedTaskTitle(text, parsed), 'Reminder from school');
      expect(
        taskNotes(title: 'Reminder from school', sharedText: text),
        text,
        reason: 'the whole message is kept, nothing is lost',
      );
    });

    test('leading blank lines are skipped', () {
      const text = '\n\n  \nPay the gas bill tomorrow';
      final parsed = parseTask(text, _now);
      expect(sharedTaskTitle(text, parsed), 'Pay the gas bill');
    });

    test('a long single line is clipped on a word boundary', () {
      final text = 'Please ${'remember ' * 20}to pay';
      final title = sharedTaskTitle(text, parseTask(text, _now));
      expect(title.length, lessThanOrEqualTo(sharedTitleLimit + 1));
      expect(title, endsWith('…'));
      expect(title, isNot(contains('remem…')), reason: 'no mid-word cut');
    });

    test('notes stay empty when the title already says everything', () {
      expect(taskNotes(title: 'Call Ali', sharedText: 'Call Ali'), isNull);
      expect(taskNotes(title: 'Call Ali'), isNull);
    });

    test('a typed task keeps its amount in the notes', () {
      expect(taskNotes(title: 'Electricity bill', amount: 'Rs 4,520'),
          'Rs 4,520');
      expect(taskNotes(title: 'Pay Rs 500 now', amount: 'Rs 500'), isNull,
          reason: 'already in the title');
    });
  });

  group('mixed shares (AC5)', () {
    SharedMediaFile media(String path, SharedMediaType type) =>
        SharedMediaFile(path: path, type: type);

    test('text alone becomes text', () {
      final s = mapSharedMedia([
        media('Pay rent tomorrow', SharedMediaType.text),
      ]);
      expect(s.text, 'Pay rent tomorrow');
      expect(s.files, isEmpty);
    });

    test('text plus an image is a document share; the text is dropped', () {
      final s = mapSharedMedia([
        media('/tmp/bill.jpg', SharedMediaType.image),
        media('here is the bill', SharedMediaType.text),
      ]);
      expect(s.files, hasLength(1));
      expect(s.text, isEmpty);
    });

    test('a shared link comes through as text', () {
      final s = mapSharedMedia([
        media('https://example.com/invoice', SharedMediaType.url),
      ]);
      expect(s.text, 'https://example.com/invoice');
    });

    test('an empty share is empty', () {
      expect(mapSharedMedia(const []).isEmpty, isTrue);
    });
  });

  group('the flow', () {
    appTest('AC1: a shared bill pre-fills the sheet; Add saves it', (
      tester,
      app,
    ) async {
      fakes.inbox.shareText('Electricity bill Rs 4,520 due 15 Nov');
      await settle(tester);

      expect(titleField, findsOneWidget);
      expect(titleText(tester), 'Electricity bill');
      expect(find.byKey(const ValueKey('parse-chip-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('parse-chip-amount')), findsOneWidget);
      expect(find.text('Rs 4,520'), findsOneWidget);
      expect(find.byKey(const ValueKey('parse-chip-domain')), findsOneWidget);
      expect(fakes.inbox.resets, 1);

      // Nothing is created until the user asks for it (ATC principle).
      expect(await tasks(app, tester), isEmpty);

      await tester.tap(find.byKey(const ValueKey('new-task-save')));
      await settle(tester);

      final saved = await tasks(app, tester);
      expect(saved, hasLength(1));
      expect(saved.single.title, 'Electricity bill');
      expect(saved.single.dueAt, DateTime(2026, 11, 15).millisecondsSinceEpoch);
      expect(saved.single.domain, 'money');
      expect(saved.single.notes, contains('Rs 4,520'));
    }, capture: makeFakes);

    appTest('AC3: a forwarded message keeps all of itself in the notes', (
      tester,
      app,
    ) async {
      const text =
          'Reminder from school\n'
          'Fee voucher Rs 12,000 due 20 Nov\n'
          'Please pay at any branch before closing.';
      fakes.inbox.shareText(text);
      await settle(tester);

      expect(titleText(tester), 'Reminder from school');
      await tester.tap(find.byKey(const ValueKey('new-task-save')));
      await settle(tester);

      final saved = (await tasks(app, tester)).single;
      expect(saved.title, 'Reminder from school');
      expect(saved.notes, text);
      expect(saved.dueAt, DateTime(2026, 11, 20).millisecondsSinceEpoch);
    }, capture: makeFakes);

    appTest('AC6: dismissing the sheet saves and logs nothing', (
      tester,
      app,
    ) async {
      fakes.inbox.shareText('Pay the water bill Rs 900 tomorrow');
      await settle(tester);
      expect(titleField, findsOneWidget);

      // Tap the barrier above the sheet to dismiss it.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);

      expect(titleField, findsNothing);
      expect(await tasks(app, tester), isEmpty);
    }, capture: makeFakes);

    appTest('a share that arrives while the app runs opens the sheet', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Vault');
      fakes.inbox.shareText('Call the plumber tomorrow');
      await settle(tester);
      expect(titleText(tester), 'Call the plumber');
    }, capture: makeFakes);

    appTest('AC2: a share that cold-starts the app opens the sheet', (
      tester,
      app,
    ) async {
      fakes.inbox.atLaunch = const SharedIn(text: 'Pay rent on 5th');
      await TestApp.restart(
        tester,
        app,
        extra: [shareInboxProvider.overrideWithValue(fakes.inbox)],
      );
      await settle(tester);
      expect(titleText(tester), 'Pay rent');
    }, capture: makeFakes);

    appTest(
      'AC4: with App Lock on, unlock comes first and the text survives',
      (tester, app) async {
        final auth = FakeAuthenticator(pass: false);
        await setSettings(
          app,
          tester,
          const UserSettingsCompanion(appLock: Value(true)),
        );
        await TestApp.restart(
          tester,
          app,
          extra: [
            authenticatorProvider.overrideWithValue(auth),
            shareInboxProvider.overrideWithValue(fakes.inbox),
          ],
        );
        await settle(tester);
        expect(find.byKey(const ValueKey('app-lock')), findsOneWidget);

        fakes.inbox.shareText('Pay the school fee Rs 12,000 tomorrow');
        await settle(tester);
        expect(
          titleField,
          findsNothing,
          reason: 'the shared text must not show over the lock screen',
        );

        auth.pass = true;
        await tester.tap(find.byKey(const ValueKey('unlock')));
        await settle(tester);

        expect(find.byKey(const ValueKey('app-lock')), findsNothing);
        expect(titleText(tester), 'Pay the school fee');
      },
      capture: makeFakes,
    );
  });
}
