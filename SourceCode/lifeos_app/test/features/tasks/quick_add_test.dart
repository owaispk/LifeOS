// PBI-010 quick add: typed (AC1), chips, voice overlay (AC4), no
// recogniser (AC5).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/features/tasks/domain/nl_parser.dart';
import 'package:lifeos_app/features/tasks/ui/quick_parse.dart';

import '../../widget_test_utils.dart';

class FakeSpeech implements SpeechInput {
  FakeSpeech(this.words, {this.available = true});
  final List<String> words;
  final bool available;
  String? locale;
  bool stopped = false;

  @override
  Future<bool> init() async => available;

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool done) onResult,
  }) async {
    locale = localeId;
    for (var i = 0; i < words.length; i++) {
      onResult(words[i], i == words.length - 1);
    }
  }

  @override
  Future<void> stop() async => stopped = true;
}

Future<void> openNewTask(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quick-action-task')));
  await tester.pumpAndSettle();
}

void main() {
  test('dropping a chip puts its words back in the title', () {
    final q = quickParse('meet Friday 5pm', DateTime(2026, 11, 8, 10));
    expect(q.title, 'Meet');
    final kept = q.drop(ParsedPart.date);
    expect(kept.title, 'Meet Friday');
    expect(
      kept.effective.dueAt(DateTime(2026, 11, 8, 10)),
      DateTime(2026, 11, 8, 17),
      reason: 'the time alone → today',
    );
  });

  appTest('AC1: typed "pay electricity bill Friday 5pm" → task + reminder', (
    tester,
    app,
  ) async {
    await openNewTask(tester);
    await tester.enterText(
      find.byKey(const ValueKey('new-task-title')),
      'pay electricity bill Friday 5pm',
    );
    await tester.pump();
    for (final part in ['date', 'time', 'domain']) {
      expect(find.byKey(ValueKey('parse-chip-$part')), findsOneWidget);
    }
    expect(find.text('Fri, 13 Nov'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-task-save')));
    await settle(tester);
    final task = (await tester.runAsync(app.repos.tasks.getAll))!.single;
    expect(task.title, 'Pay electricity bill');
    expect(
      DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
      DateTime(2026, 11, 13, 17),
    );
    expect(task.allDay, isFalse);
    expect(task.domain, 'money');
    final reminders = await tester.runAsync(app.repos.taskReminders.getAll);
    expect(
      DateTime.fromMillisecondsSinceEpoch(reminders!.single.fireAt),
      DateTime(2026, 11, 13, 17),
      reason: 'reminder at the due time',
    );
  });

  appTest('tapping a chip away keeps that part out of the task', (
    tester,
    app,
  ) async {
    await openNewTask(tester);
    await tester.enterText(
      find.byKey(const ValueKey('new-task-title')),
      'meet Friday 5pm',
    );
    await tester.pump();
    final chip = find.byKey(const ValueKey('parse-chip-date'));
    await tester.tap(find.byTooltip('Remove Fri, 13 Nov'));
    await tester.pump();
    expect(chip, findsNothing);
    await tester.tap(find.byKey(const ValueKey('new-task-save')));
    await settle(tester);
    final task = (await tester.runAsync(app.repos.tasks.getAll))!.single;
    expect(task.title, 'Meet Friday');
    expect(
      DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
      DateTime(2026, 11, 8, 17),
    );
  });

  appTest(
    'AC4: the voice overlay shows live words and chips; Create saves',
    (tester, app) async {
      await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-action-voice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('voice-overlay')), findsOneWidget);
      expect(find.text('call Ahmed tomorrow 6pm'), findsOneWidget);
      expect(find.byKey(const ValueKey('parse-chip-time')), findsOneWidget);
      expect(speech.locale, 'en_US');
      await tester.tap(find.byKey(const ValueKey('voice-create')));
      await settle(tester);
      expect(find.byKey(const ValueKey('voice-overlay')), findsNothing);
      final task = (await tester.runAsync(app.repos.tasks.getAll))!.single;
      expect(task.title, 'Call Ahmed');
      expect(
        DateTime.fromMillisecondsSinceEpoch(task.dueAt!),
        DateTime(2026, 11, 9, 18),
      );
      expect(task.domain, 'people');
      expect(speech.stopped, isTrue);
    },
    extra: () {
      speech = FakeSpeech(['call', 'call Ahmed', 'call Ahmed tomorrow 6pm']);
      return [speechInputProvider.overrideWithValue(speech)];
    },
  );

  appTest('AC5: no recogniser → a friendly message, no crash', (
    tester,
    app,
  ) async {
    await tester.tap(find.byKey(const ValueKey('quick-action-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-action-voice')));
    await tester.pumpAndSettle();
    expect(
      find.text("Voice isn't available on this phone — type instead"),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('voice-create')), findsNothing);
  });
}

late FakeSpeech speech;
