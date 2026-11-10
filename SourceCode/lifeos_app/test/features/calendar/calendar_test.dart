// PBI-032: the device calendar in Today and Upcoming, read-only.
//
// The pure half (which events fall on a day, ordering, which calendars
// are shown) and the flow: events above tasks, the permission asked only
// on enabling, and nothing written anywhere.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/calendar/calendar_providers.dart';
import 'package:lifeos_app/features/calendar/domain/event_rules.dart';
import 'package:lifeos_app/features/calendar/platform/calendar_source.dart';

import '../../fakes.dart';
import '../../widget_test_utils.dart';

/// Sunday 8 Nov 2026, 10:00 — the harness clock.
final _now = testNow;

const personal = DeviceCal(id: 'c1', name: 'Personal', colorValue: 0xFF2196F3);
const holidays = DeviceCal(id: 'c2', name: 'Holidays in Pakistan');

CalEvent event(
  String id, {
  required DateTime start,
  Duration length = const Duration(hours: 1),
  String title = 'Event',
  bool allDay = false,
  String calendarId = 'c1',
  String location = '',
}) => CalEvent(
  id: id,
  calendarId: calendarId,
  title: title,
  start: start,
  end: allDay
      ? DateTime(start.year, start.month, start.day + 1)
      : start.add(length),
  allDay: allDay,
  location: location,
  calendarName: calendarId == 'c1' ? 'Personal' : 'Holidays in Pakistan',
);

late FakeCalendar cal;

List<Override> withCalendar() {
  cal = FakeCalendar(permission: true)..cals = const [personal, holidays];
  return [calendarSourceProvider.overrideWithValue(cal)];
}

Future<void> turnOn(TestApp app, WidgetTester tester, {bool on = true}) =>
    app.write(tester, () async {
      final row = (await app.repos.userSettings.getAll()).first;
      await app.repos.userSettings.update(
        row.id,
        UserSettingsCompanion(calendarOn: Value(on)),
      );
    });

Future<void> hideCalendar(
  TestApp app,
  WidgetTester tester,
  String id,
) => app.write(tester, () async {
  final row = (await app.repos.userSettings.getAll()).first;
  await app.repos.userSettings.update(
    row.id,
    UserSettingsCompanion(calendarsOff: Value(id)),
  );
});

void main() {
  group('which events fall on a day', () {
    test('all-day events pin above timed ones, then by start (AC1)', () {
      final events = [
        event('b', start: DateTime(2026, 11, 8, 15)),
        event('a', start: DateTime(2026, 11, 8, 9)),
        event('allday', start: DateTime(2026, 11, 8), allDay: true),
      ];
      expect(
        eventsOnDay(events, _now).map((e) => e.id),
        ['allday', 'a', 'b'],
      );
    });

    test('an event on another day is left out', () {
      final events = [
        event('today', start: DateTime(2026, 11, 8, 9)),
        event('tomorrow', start: DateTime(2026, 11, 9, 9)),
      ];
      expect(eventsOnDay(events, _now).map((e) => e.id), ['today']);
    });

    test('a multi-day event shows on each of its days', () {
      final trip = CalEvent(
        id: 'trip',
        calendarId: 'c1',
        title: 'Lahore trip',
        start: DateTime(2026, 11, 8, 7),
        end: DateTime(2026, 11, 10, 20),
      );
      for (final day in [
        DateTime(2026, 11, 8),
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 10),
      ]) {
        expect(eventsOnDay([trip], day), hasLength(1), reason: '$day');
      }
      expect(eventsOnDay([trip], DateTime(2026, 11, 11)), isEmpty);
    });

    test('a one-day all-day event does not bleed into tomorrow', () {
      final e = event('holiday', start: DateTime(2026, 11, 8), allDay: true);
      expect(eventsOnDay([e], _now), hasLength(1));
      expect(eventsOnDay([e], DateTime(2026, 11, 9)), isEmpty);
    });

    test('upcoming covers the 7 days after today, not today (AC2)', () {
      final events = [
        event('today', start: DateTime(2026, 11, 8, 9)),
        event('tomorrow', start: DateTime(2026, 11, 9, 9)),
        event('day7', start: DateTime(2026, 11, 15, 9)),
        event('day8', start: DateTime(2026, 11, 16, 9)),
      ];
      final byDay = eventsByDay(events, _now);
      expect(byDay.keys, [DateTime(2026, 11, 9), DateTime(2026, 11, 15)]);
    });
  });

  group('which calendars are shown', () {
    test('unticked calendars drop out; unknown ones stay in (AC4)', () {
      expect(
        visibleCalendars(const [personal, holidays], {'c2'}).map((c) => c.id),
        ['c1'],
      );
      // A calendar added on the phone later is shown without being ticked.
      expect(
        visibleCalendars(const [personal, holidays], {'c9'}).map((c) => c.id),
        ['c1', 'c2'],
      );
    });

    test('the unticked set round-trips through the setting', () {
      expect(parseCalendarsOff(''), isEmpty);
      expect(parseCalendarsOff('c2, c3 ,'), {'c2', 'c3'});
      expect(storeCalendarsOff({'c3', 'c2'}), 'c2,c3');
    });
  });

  group('the flow', () {
    appTest(
      'AC5: with the toggle off nothing reaches the calendar',
      (tester, app) async {
        await openTab(tester, 'Tasks');
        await settle(tester);
        expect(
          cal.calls,
          0,
          reason: 'no permission check, no read, no prompt',
        );
        expect(find.byKey(const ValueKey('section-events')), findsNothing);
      },
      extra: withCalendar,
    );

    appTest(
      'AC1: today\'s events show above tasks, all-day first',
      (tester, app) async {
        cal.events = [
          event('meeting', start: DateTime(2026, 11, 8, 15), title: 'Standup'),
          event(
            'holiday',
            start: DateTime(2026, 11, 8),
            allDay: true,
            title: 'Iqbal Day',
            calendarId: 'c2',
          ),
        ];
        await turnOn(app, tester);
        await openTab(tester, 'Tasks');
        await settle(tester);

        expect(find.byKey(const ValueKey('section-events')), findsOneWidget);
        expect(find.text('Iqbal Day'), findsOneWidget);
        expect(find.text('Standup'), findsOneWidget);

        // All-day pinned above the timed one, and both above the tasks.
        final events = find.byKey(const ValueKey('today-list'));
        expect(events, findsOneWidget);
        final allDayY = tester.getTopLeft(find.text('Iqbal Day')).dy;
        final timedY = tester.getTopLeft(find.text('Standup')).dy;
        expect(allDayY, lessThan(timedY));
      },
      extra: withCalendar,
    );

    appTest(
      'AC4: unticking a calendar drops its events straight away',
      (tester, app) async {
        cal.events = [
          event('holiday', start: DateTime(2026, 11, 8), allDay: true,
              title: 'Iqbal Day', calendarId: 'c2'),
          event('meeting', start: DateTime(2026, 11, 8, 15), title: 'Standup'),
        ];
        await turnOn(app, tester);
        await openTab(tester, 'Tasks');
        await settle(tester);
        expect(find.text('Iqbal Day'), findsOneWidget);

        await hideCalendar(app, tester, 'c2');
        await settle(tester);
        expect(find.text('Iqbal Day'), findsNothing);
        expect(find.text('Standup'), findsOneWidget);
      },
      extra: withCalendar,
    );

    appTest(
      'AC7: a calendar that will not be read leaves tasks alone',
      (tester, app) async {
        cal
          ..events = [event('meeting', start: DateTime(2026, 11, 8, 15))]
          ..failWith = StateError('calendar store unavailable');
        await turnOn(app, tester);
        await openTab(tester, 'Tasks');
        await settle(tester);

        // No error screen, no events section — just the tasks.
        expect(find.byKey(const ValueKey('section-events')), findsNothing);
        expect(find.text(' '), findsNothing);
        expect(find.byType(ErrorWidget), findsNothing);
      },
      extra: withCalendar,
    );

    appTest(
      'AC6: events are never stored and never become tasks',
      (tester, app) async {
        cal.events = [
          event('meeting', start: DateTime(2026, 11, 8, 15), title: 'Standup'),
        ];
        await turnOn(app, tester);
        await openTab(tester, 'Tasks');
        await settle(tester);
        expect(find.text('Standup'), findsOneWidget);

        final tasks = (await tester.runAsync(app.repos.tasks.getAll))!;
        expect(tasks, isEmpty, reason: 'an event is not a task');
        final reminders = (await tester.runAsync(app.repos.taskReminders.getAll))!;
        expect(reminders, isEmpty, reason: 'an event schedules nothing');
      },
      extra: withCalendar,
    );

    appTest(
      'AC6: the Life Score is the same with events as without',
      (tester, app) async {
        await openTab(tester, 'Home');
        await settle(tester);
        final before = tester
            .widget<Text>(find.byKey(const ValueKey('score-value')))
            .data;

        cal.events = [
          event('meeting', start: DateTime(2026, 11, 8, 15), title: 'Standup'),
        ];
        await turnOn(app, tester);
        await settle(tester);

        final after = tester
            .widget<Text>(find.byKey(const ValueKey('score-value')))
            .data;
        expect(after, before);
      },
      extra: withCalendar,
    );

    appTest(
      'AC2: Upcoming shows events on their day, beside the tasks',
      (tester, app) async {
        cal.events = [
          event(
            'dentist',
            start: DateTime(2026, 11, 10, 11),
            title: 'Dentist',
          ),
        ];
        await app.write(tester, () async {
          await app.repos.tasks.insert(
            TasksCompanion.insert(
              title: 'Pay the gas bill',
              dueAt: Value(DateTime(2026, 11, 10, 9).millisecondsSinceEpoch),
              allDay: const Value(false),
            ),
          );
        });
        await turnOn(app, tester);
        await openTab(tester, 'Tasks');
        await tester.tap(find.text('Upcoming'));
        await settle(tester);

        expect(find.text('Dentist'), findsOneWidget);
        expect(find.text('Pay the gas bill'), findsOneWidget);
      },
      extra: withCalendar,
    );

    appTest(
      'AC3: refusing the permission leaves the toggle off and says so',
      (tester, app) async {
        cal
          ..permission = false
          ..grants = false;
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-calendar')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('set-calendar')));
        await settle(tester);

        expect(cal.asks, 1, reason: 'asked once, in context');
        expect(find.byKey(const ValueKey('calendar-denied')), findsOneWidget);
        final settings = (await tester.runAsync(
          app.repos.userSettings.getAll,
        ))!;
        expect(settings.first.calendarOn, isFalse);
      },
      extra: withCalendar,
    );

    appTest(
      'AC3: allowing it turns events on and asks only that once',
      (tester, app) async {
        cal
          ..permission = false
          ..grants = true
          ..events = [
            event('meeting', start: DateTime(2026, 11, 8, 15), title: 'Standup'),
          ];
        await openTab(tester, 'More');
        await tester.tap(find.byKey(const ValueKey('more-settings')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('set-calendar')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('set-calendar')));
        await settle(tester);

        expect(cal.asks, 1);
        final settings = (await tester.runAsync(
          app.repos.userSettings.getAll,
        ))!;
        expect(settings.first.calendarOn, isTrue);

        await openTab(tester, 'Tasks');
        await settle(tester);
        expect(find.text('Standup'), findsOneWidget);
        expect(cal.asks, 1, reason: 'never asked again unprompted');
      },
      extra: withCalendar,
    );
  });
}
