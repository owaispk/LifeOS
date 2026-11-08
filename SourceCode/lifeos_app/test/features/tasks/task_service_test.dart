// PBI-009: TaskService against a real (in-memory) SQLite database.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/tasks/data/task_service.dart';
import 'package:lifeos_app/features/tasks/domain/task_rules.dart';

import '../../data/db_test_utils.dart';

void main() {
  final now = DateTime(2026, 11, 8, 10);
  late AppDatabase db;
  late Repositories repos;
  late TaskService service;

  setUp(() async {
    db = memoryDb();
    repos = await openRepos(db);
    service = TaskService(repos, now: () => now);
  });
  tearDown(() => db.close());

  Future<List<Task>> openTasks() async =>
      (await repos.tasks.getAll()).where(isOpen).toList();

  test('AC1: a task needs only a title and shows up in Anytime', () async {
    final t = await service.create(title: '  Review CV  ');
    expect(t.title, 'Review CV');
    expect(t.dueAt, isNull);
    expect(t.status, 'open');
    expect(t.durationMin, 30);
    expect(todaySections(await openTasks(), now).keys, [TodaySection.anytime]);
    expect(() => service.create(title: '   '), throwsArgumentError);
  });

  test('all-day due dates are stored as local midnight', () async {
    final t = await service.create(
      title: 'Pay rent',
      due: DateTime(2026, 11, 10, 15, 45),
    );
    expect(localDue(t), DateTime(2026, 11, 10));
    expect(t.allDay, isTrue);
  });

  test('AC3: completing sets done + completed_at; undo reopens', () async {
    final t = await service.create(title: 'Call electrician');
    final result = await service.complete(t.id);
    expect(result.nextTaskId, isNull);

    final done = (await repos.tasks.getById(t.id))!;
    expect(done.status, 'done');
    expect(done.completedAt, now.toUtc().millisecondsSinceEpoch);
    expect(todaySections(await openTasks(), now), isEmpty);

    await service.undoComplete(result);
    final reopened = (await repos.tasks.getById(t.id))!;
    expect(reopened.status, 'open');
    expect(reopened.completedAt, isNull);
  });

  test('AC4: a repeating task creates exactly one next occurrence', () async {
    final t = await service.create(
      title: 'Water plants',
      due: DateTime(2026, 11, 8),
      repeat: RepeatFreq.daily,
      priority: 2,
      domain: 'health',
    );
    await service.addSubtask(t.id, 'Balcony');
    final sub2 = await service.addSubtask(t.id, 'Kitchen');
    await service.toggleSubtask(sub2);

    final result = await service.complete(t.id);
    final open = await openTasks();
    expect(open, hasLength(1));
    final next = open.single;
    expect(next.id, result.nextTaskId);
    expect(localDue(next), DateTime(2026, 11, 9));
    expect(next.repeatRule, 'FREQ=DAILY');
    expect(
      (next.priority, next.domain, next.title),
      (2, 'health', 'Water plants'),
    );

    final copied = await service.subtasksOf(next.id);
    expect(copied.map((s) => (s.title, s.done)), [
      ('Balcony', false),
      ('Kitchen', false), // copied unchecked
    ]);

    // Undo removes the next occurrence and its subtasks.
    await service.undoComplete(result);
    final after = await openTasks();
    expect(after.map((t) => t.id), [t.id]);
    expect(await service.subtasksOf(next.id), isEmpty);
  });

  test('AC4: weekly and monthly repeats', () async {
    final weekly = await service.create(
      title: 'Groceries',
      due: DateTime(2026, 11, 8),
      repeat: RepeatFreq.weekly,
    );
    final monthly = await service.create(
      title: 'Rent',
      due: DateTime(2026, 10, 31),
      repeat: RepeatFreq.monthly,
    );
    expect(monthly.repeatRule, 'FREQ=MONTHLY;BYMONTHDAY=31');

    final w = await service.complete(weekly.id);
    final m = await service.complete(monthly.id);
    expect(
      localDue((await repos.tasks.getById(w.nextTaskId!))!),
      DateTime(2026, 11, 15),
    );
    expect(
      localDue((await repos.tasks.getById(m.nextTaskId!))!),
      DateTime(2026, 11, 30),
    ); // Nov has 30 days
  });

  test('AC5: snooze moves the due time and makes the task timed', () async {
    final t = await service.create(title: 'Email landlord', due: now);
    final snoozed = await service.snooze(
      t.id,
      snoozeTarget(SnoozeOption.tomorrow, now),
    );
    expect(localDue(snoozed), DateTime(2026, 11, 9, 9));
    expect(snoozed.allDay, isFalse);
    expect(todaySections(await openTasks(), now), isEmpty);
    expect(upcomingByDay(await openTasks(), now).keys, [DateTime(2026, 11, 9)]);
  });

  test('skip, mute rule and delete', () async {
    final rule = await repos.atcRules.insert(
      AtcRulesCompanion.insert(
        kind: 'fixed',
        name: 'Rent',
        status: const Value('active'),
      ),
    );
    final t = await repos.tasks.insert(
      TasksCompanion.insert(title: 'Pay rent', atcRuleId: Value(rule.id)),
    );

    await service.skip(t.id);
    expect((await repos.tasks.getById(t.id))!.status, 'skipped');

    await service.muteRule(rule.id);
    expect((await repos.atcRules.getById(rule.id))!.status, 'paused');

    final other = await service.create(title: 'Temp');
    await service.addSubtask(other.id, 'part');
    await service.delete(other.id);
    expect(await repos.tasks.getById(other.id), isNull);
    expect(await service.subtasksOf(other.id), isEmpty);
  });

  test('every task change is queued for sync', () async {
    final t = await service.create(title: 'Sync me');
    await service.complete(t.id);
    final ops = await opsFor(db, t.id);
    expect(ops.map((o) => o.op), ['insert', 'update']);
  });
}
