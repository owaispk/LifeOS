// PBI-009: pure rules — Today ordering (AC2), Upcoming (AC6),
// repeat (AC4), snooze (AC5).
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/tasks/domain/task_rules.dart';

/// Sunday 8 Nov 2026, 10:00 local.
final now = DateTime(2026, 11, 8, 10);

var _seq = 0;
Task task(
  String title, {
  DateTime? due,
  bool allDay = true,
  int priority = 1,
  String status = 'open',
  String? atc,
  String domain = 'mind',
}) {
  _seq++;
  return Task(
    id: 'id-${_seq.toString().padLeft(4, '0')}',
    userId: 'u',
    updatedAt: 0,
    version: 1,
    domain: domain,
    title: title,
    dueAt: due?.millisecondsSinceEpoch,
    allDay: allDay,
    priority: priority,
    durationMin: 30,
    status: status,
    atcRuleId: atc,
  );
}

List<String> titles(Iterable<Task> l) => l.map((t) => t.title).toList();

void main() {
  group('todaySections', () {
    test('AC2: Overdue → Timed → Payments ⚡ → Anytime, each sorted', () {
      final tasks = [
        task('anytime low', priority: 0),
        task('payment later', due: DateTime(2026, 11, 8), atc: 'r1'),
        task('timed 14:00', due: DateTime(2026, 11, 8, 14), allDay: false),
        task('overdue yesterday', due: DateTime(2026, 11, 7)),
        task('anytime high', priority: 2),
        task('timed 11:00', due: DateTime(2026, 11, 8, 11), allDay: false),
        task(
          'overdue 08:00 today',
          due: DateTime(2026, 11, 8, 8),
          allDay: false,
        ),
        task('due today all-day', due: DateTime(2026, 11, 8)),
        task('overdue payment', due: DateTime(2026, 11, 5), atc: 'r2'),
        task('anytime med'),
        // Excluded:
        task('tomorrow', due: DateTime(2026, 11, 9)),
        task('done', status: 'done'),
        task('skipped', status: 'skipped'),
      ];

      final s = todaySections(tasks, now);
      expect(s.keys.toList(), [
        TodaySection.overdue,
        TodaySection.timed,
        TodaySection.payments,
        TodaySection.anytime,
      ]);
      expect(titles(s[TodaySection.overdue]!), [
        'overdue payment',
        'overdue yesterday',
        'overdue 08:00 today',
      ]);
      expect(titles(s[TodaySection.timed]!), ['timed 11:00', 'timed 14:00']);
      expect(titles(s[TodaySection.payments]!), ['payment later']);
      expect(
        titles(s[TodaySection.anytime]!),
        // priority (high first), then age (older first)
        ['anytime high', 'due today all-day', 'anytime med', 'anytime low'],
      );
    });

    test('AC1: a title-only task lands in Anytime', () {
      final s = todaySections([task('just a title')], now);
      expect(s.keys, [TodaySection.anytime]);
    });

    test('empty sections are omitted', () {
      expect(todaySections([], now), isEmpty);
      expect(todaySections([task('x', status: 'done')], now), isEmpty);
    });

    test('a timed task later today is not overdue', () {
      final t = task('t', due: DateTime(2026, 11, 8, 10, 1), allDay: false);
      expect(isOverdue(t, now), isFalse);
      expect(todaySections([t], now).keys, [TodaySection.timed]);
    });
  });

  group('upcomingByDay', () {
    test('AC6: next 7 days grouped by day, empty days hidden', () {
      final tasks = [
        task('today', due: DateTime(2026, 11, 8, 18), allDay: false),
        task('tomorrow b', due: DateTime(2026, 11, 9, 15), allDay: false),
        task('tomorrow a', due: DateTime(2026, 11, 9)),
        task('in 3 days', due: DateTime(2026, 11, 11)),
        task('in 7 days', due: DateTime(2026, 11, 15, 23, 59), allDay: false),
        task('in 8 days', due: DateTime(2026, 11, 16)),
        task('undated'),
        task('done tomorrow', due: DateTime(2026, 11, 9), status: 'done'),
      ];
      final days = upcomingByDay(tasks, now);
      expect(days.keys.toList(), [
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 15),
      ]);
      expect(titles(days[DateTime(2026, 11, 9)]!), [
        'tomorrow a',
        'tomorrow b',
      ]);
    });
  });

  group('tasksByDomain', () {
    test('groups open tasks by domain in spec order, undated last', () {
      final groups = tasksByDomain([
        task('w', domain: 'work'),
        task('m undated', domain: 'money'),
        task('m dated', domain: 'money', due: DateTime(2026, 12, 1)),
        task('mind', domain: 'mind'),
      ]);
      expect(groups.keys.toList(), ['mind', 'money', 'work']);
      expect(titles(groups['money']!), ['m dated', 'm undated']);
    });
  });

  group('RepeatRule', () {
    test('parses and formats the supported RRULE subset', () {
      final r = RepeatRule.parse('FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=31')!;
      expect(r.freq, RepeatFreq.monthly);
      expect(r.interval, 2);
      expect(r.monthDay, 31);
      expect(r.format(), 'FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=31');
      expect(RepeatRule.parse('FREQ=DAILY')!.format(), 'FREQ=DAILY');
      expect(RepeatRule.parse(null), isNull);
      expect(RepeatRule.parse('FREQ=HOURLY'), isNull);
    });

    test('daily and weekly keep the time of day', () {
      final from = DateTime(2026, 11, 8, 17, 30);
      expect(
        const RepeatRule(RepeatFreq.daily).after(from),
        DateTime(2026, 11, 9, 17, 30),
      );
      expect(
        const RepeatRule(RepeatFreq.weekly, interval: 2).after(from),
        DateTime(2026, 11, 22, 17, 30),
      );
      expect(
        const RepeatRule(RepeatFreq.daily).after(DateTime(2026, 12, 31)),
        DateTime(2027, 1, 1),
      );
    });

    test('monthly on the 31st clamps without drifting', () {
      final rule = RepeatRule.from(RepeatFreq.monthly, DateTime(2027, 1, 31));
      final feb = rule.after(DateTime(2027, 1, 31));
      expect(feb, DateTime(2027, 2, 28));
      expect(rule.after(feb), DateTime(2027, 3, 31));
      expect(rule.after(DateTime(2027, 3, 31)), DateTime(2027, 4, 30));
      // Leap year.
      expect(rule.after(DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
      // Year rollover.
      expect(rule.after(DateTime(2027, 12, 31)), DateTime(2028, 1, 31));
    });

    test('AC4: next occurrence rolls forward past missed cycles', () {
      const daily = RepeatRule(RepeatFreq.daily);
      // Due 1 Nov, completed on 8 Nov → next is today, not 2 Nov.
      expect(
        daily.nextOccurrence(DateTime(2026, 11, 1), now),
        DateTime(2026, 11, 8),
      );
      // Due today → tomorrow.
      expect(
        daily.nextOccurrence(DateTime(2026, 11, 8), now),
        DateTime(2026, 11, 9),
      );
      const weekly = RepeatRule(RepeatFreq.weekly);
      expect(
        weekly.nextOccurrence(DateTime(2026, 10, 20), now),
        DateTime(2026, 11, 10),
      );
    });

    test('describe', () {
      expect(const RepeatRule(RepeatFreq.weekly).describe(), 'Every week');
      expect(
        const RepeatRule(RepeatFreq.daily, interval: 3).describe(),
        'Every 3 days',
      );
    });
  });

  group('snoozeTarget', () {
    test('AC5: tomorrow is 09:00 next day', () {
      expect(
        snoozeTarget(SnoozeOption.tomorrow, now),
        DateTime(2026, 11, 9, 9),
      );
      expect(
        snoozeTarget(SnoozeOption.tomorrow, DateTime(2026, 11, 30, 23)),
        DateTime(2026, 12, 1, 9),
      );
    });

    test('tonight is 20:00, or +1 h when already later', () {
      expect(
        snoozeTarget(SnoozeOption.tonight, now),
        DateTime(2026, 11, 8, 20),
      );
      expect(
        snoozeTarget(SnoozeOption.tonight, DateTime(2026, 11, 8, 21, 15)),
        DateTime(2026, 11, 8, 22, 15),
      );
    });
  });
}
