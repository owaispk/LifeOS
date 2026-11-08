// PBI-011 Overload Shield — pure capacity maths (AC1, AC2, AC4).
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/tasks/domain/overload.dart';

/// Sunday 8 Nov 2026, 10:00. Monday is 9 Nov.
final now = DateTime(2026, 11, 8, 10);
final mon = DateTime(2026, 11, 9);
final tue = DateTime(2026, 11, 10);
final wed = DateTime(2026, 11, 11);
final thu = DateTime(2026, 11, 12);

var _seq = 0;
Task task(
  DateTime? due,
  int minutes, {
  String status = 'open',
  String? atc,
  bool allDay = true,
}) {
  _seq++;
  return Task(
    id: 't${_seq.toString().padLeft(4, '0')}',
    userId: 'u',
    updatedAt: 0,
    version: 1,
    domain: 'mind',
    title: 'task $_seq',
    dueAt: due?.millisecondsSinceEpoch,
    allDay: allDay,
    priority: 1,
    durationMin: minutes,
    status: status,
    atcRuleId: atc,
  );
}

OverloadCheck? check(
  List<Task> tasks,
  DateTime day,
  int minutes, {
  bool isAtc = false,
  String? exclude,
}) => checkOverload(
  tasks: tasks,
  day: day,
  durationMin: minutes,
  capacityMin: 360,
  now: now,
  isAtc: isAtc,
  excludeTaskId: exclude,
);

void main() {
  group('day load', () {
    test('sums open, dated tasks on that local day only', () {
      final tasks = [
        task(mon, 120),
        task(DateTime(2026, 11, 9, 23, 30), 60, allDay: false),
        task(mon, 90, status: 'done'),
        task(null, 300), // undated never counts
        task(tue, 45),
      ];
      expect(dayLoadMin(tasks, mon), 180);
      expect(dayLoadMin(tasks, DateTime(2026, 11, 9, 15)), 180);
    });

    test('percent and isFull', () {
      expect(DayLoad(mon, 330, 360).percent, 92);
      expect(DayLoad(mon, 360, 360).isFull, isFalse);
      expect(DayLoad(mon, 361, 360).isFull, isTrue);
      expect(DayLoad(mon, 0, 0).percent, 0);
    });
  });

  group('AC1: when the dialog appears', () {
    test('60 min onto a 5.5 h day (of 6 h) → overloaded', () {
      final c = check([task(mon, 330)], mon, 60)!;
      expect(c.loadWithTaskMin, 390);
      expect(formatHours(c.loadWithTaskMin), '6.5h');
      expect(formatHours(c.capacityMin), '6h');
    });

    test('60 min onto a 4 h day → fits, no dialog', () {
      expect(check([task(mon, 240)], mon, 60), isNull);
    });

    test('exactly 100% still fits', () {
      expect(check([task(mon, 300)], mon, 60), isNull);
    });

    test('undated tasks are never checked', () {
      expect(
        checkOverload(
          tasks: [task(mon, 600)],
          day: null,
          durationMin: 60,
          capacityMin: 360,
          now: now,
        ),
        isNull,
      );
    });

    test('a task being rescheduled does not count against itself', () {
      final self = task(mon, 300);
      expect(check([self, task(mon, 50)], mon, 300, exclude: self.id), isNull);
    });
  });

  group('AC2: suggested day', () {
    test('nearest later day under 70% that also fits the task', () {
      final tasks = [
        task(mon, 330), // the full day
        task(tue, 300), // 83% → too busy
        task(wed, 270), // 75% → not under 70%
        task(thu, 240), // 67% and 240+60 ≤ 360 → ✓
      ];
      expect(check(tasks, mon, 60)!.suggested, thu);
    });

    test('an empty next day is suggested straight away', () {
      expect(check([task(mon, 330)], mon, 60)!.suggested, tue);
    });

    test('a light day that the task would overflow is skipped', () {
      // Tue is at 50% but a 4 h task would push it to 117%.
      final tasks = [task(mon, 330), task(tue, 180)];
      expect(check(tasks, mon, 240)!.suggested, wed);
    });

    test('no suggestion when nothing fits in 14 days', () {
      final tasks = [
        for (var i = 0; i <= 15; i++) task(DateTime(2026, 11, 9 + i), 300),
      ];
      expect(check(tasks, mon, 120)!.suggested, isNull);
    });

    test('placing on a past day suggests from today', () {
      final c = checkOverload(
        tasks: [task(DateTime(2026, 11, 5), 400)],
        day: DateTime(2026, 11, 5),
        durationMin: 30,
        capacityMin: 360,
        now: now,
      )!;
      expect(c.suggested, DateTime(2026, 11, 8));
    });
  });

  group('AC4: ATC payment tasks', () {
    test('never trigger the dialog', () {
      expect(check([task(mon, 600)], mon, 60, isAtc: true), isNull);
    });

    test('still count toward the day load', () {
      final tasks = [task(mon, 300, atc: 'rule-1')];
      expect(dayLoadMin(tasks, mon), 300);
      expect(check(tasks, mon, 90), isNotNull);
    });
  });

  test('the dialog week runs Monday–Sunday and includes the new task', () {
    final c = check([task(mon, 330), task(wed, 60)], mon, 60)!;
    expect(c.week.map((d) => d.day.weekday), [1, 2, 3, 4, 5, 6, 7]);
    expect(c.week.first.loadMin, 390);
    expect(c.week[2].loadMin, 60);
  });

  test('formatHours', () {
    expect(formatHours(45), '45m');
    expect(formatHours(60), '1h');
    expect(formatHours(390), '6.5h');
    expect(formatHours(345), '5.8h');
  });
}
