// PBI-012: reminders + actions + sync against a real (in-memory) database
// and a fake notification gateway (the device-only parts are AC1/AC4).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/reminders/data/reminder_service.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:lifeos_app/features/reminders/reminder_sync.dart';
import 'package:lifeos_app/features/tasks/data/task_service.dart';
import 'package:lifeos_app/features/tasks/domain/task_rules.dart';

import '../../data/db_test_utils.dart';
import '../../fakes.dart';

void main() {
  final now = DateTime(2026, 11, 8, 10);
  late AppDatabase db;
  late Repositories repos;
  late TaskService tasks;
  late ReminderService reminders;
  late FakeGateway gateway;
  late ReminderSync sync;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    tasks = TaskService(repos, now: () => now);
    reminders = ReminderService(repos, now: () => now);
    gateway = FakeGateway();
    sync = ReminderSync(repos, gateway, now: () => now);
  });
  tearDown(() => db.close());

  Future<String> payloadFor(String taskId) async {
    final planned = withoutDigest(await sync.resync());
    return planned.firstWhere((p) => p.taskId == taskId).payload;
  }

  group('reminders on tasks', () {
    test('a timed task gets a default reminder at its due time', () async {
      final t = await tasks.create(
        title: 'Call electrician',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      final list = await reminders.remindersOf(t.id);
      expect(
        list.single.fireAt,
        DateTime(2026, 11, 8, 16).millisecondsSinceEpoch,
      );

      final allDay = await tasks.create(
        title: 'Pay rent',
        due: DateTime(2026, 11, 9),
      );
      expect(await reminders.remindersOf(allDay.id), isEmpty);
    });

    test('add skips exact duplicates; remove soft-deletes', () async {
      final t = await tasks.create(title: 'x');
      final at = DateTime(2026, 11, 9, 8);
      final r = (await reminders.add(t.id, at))!;
      expect(await reminders.add(t.id, at), isNull);
      await reminders.remove(r.id);
      expect(await reminders.remindersOf(t.id), isEmpty);
    });

    test('rescheduling moves reminders by the same amount', () async {
      final t = await tasks.create(
        title: 'Meeting',
        due: DateTime(2026, 11, 9, 15),
        allDay: false,
      );
      await reminders.add(t.id, DateTime(2026, 11, 9, 14)); // 1 h before
      await tasks.reschedule(t.id, DateTime(2026, 11, 10, 11));
      final list = await reminders.remindersOf(t.id);
      expect(list.map((r) => DateTime.fromMillisecondsSinceEpoch(r.fireAt)), [
        DateTime(2026, 11, 10, 10),
        DateTime(2026, 11, 10, 11),
      ]);

      // Removing the due date drops its reminders.
      await tasks.reschedule(t.id, null, allDay: true);
      expect(await reminders.remindersOf(t.id), isEmpty);
    });

    test('a repeating task carries its reminders to the next one', () async {
      final t = await tasks.create(
        title: 'Standup',
        due: DateTime(2026, 11, 8, 9, 30),
        allDay: false,
        repeat: RepeatFreq.daily,
      );
      final result = await tasks.complete(t.id);
      final next = await reminders.remindersOf(result.nextTaskId!);
      expect(
        DateTime.fromMillisecondsSinceEpoch(next.single.fireAt),
        DateTime(2026, 11, 9, 9, 30),
      );
    });
  });

  group('AC5: completing or deleting cancels pending notifications', () {
    test('complete → gone; undo → back; delete → gone', () async {
      final t = await tasks.create(
        title: 'Call electrician',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      expect((withoutDigest(await sync.resync())).map((p) => p.taskId), [t.id]);
      expect(scheduledReminders(gateway), hasLength(1));

      final done = await tasks.complete(t.id);
      expect(withoutDigest(await sync.resync()), isEmpty);
      expect(scheduledReminders(gateway), isEmpty);

      await tasks.undoComplete(done);
      expect(withoutDigest(await sync.resync()), hasLength(1));

      await tasks.delete(t.id);
      expect(withoutDigest(await sync.resync()), isEmpty);
    });

    test('the sync reacts to writes on its own (debounced)', () async {
      final live = ReminderSync(
        repos,
        gateway,
        now: () => now,
        debounce: Duration.zero,
      );
      await live.start();
      final t = await tasks.create(
        title: 'Auto',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scheduledReminders(gateway).map((p) => p.taskId), [t.id]);

      await tasks.complete(t.id);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(scheduledReminders(gateway), isEmpty);
      await live.stop();
    });

    test('resume refreshes the timezone, then resyncs', () async {
      await sync.onResume();
      expect(gateway.timezoneRefreshes, 1);
    });
  });

  group('actions (handled without opening the UI)', () {
    test('AC2: Paid ✓ completes the task and marks the payment paid', () async {
      final t = await tasks.create(
        title: 'Electricity bill',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      final p = await repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'Electricity',
          dueDate: '2026-11-08',
          periodMonth: '2026-11-01',
          taskId: Value(t.id),
          amountMinor: const Value(485000),
        ),
      );
      final payload = await payloadFor(t.id);
      expect(scheduledReminders(gateway).single.kind, ReminderKind.payment);

      expect(
        await reminders.handleAction(ReminderActions.paid, payload),
        isTrue,
      );
      expect((await repos.tasks.getById(t.id))!.status, 'done');
      final paid = (await repos.payments.getById(p.id))!;
      expect(paid.status, 'paid');
      expect(paid.paidAt, now.toUtc().millisecondsSinceEpoch);
      expect(withoutDigest(await sync.resync()), isEmpty);
    });

    test('Done ✓ completes the task', () async {
      final t = await tasks.create(
        title: 'x',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      await reminders.handleAction(
        ReminderActions.done,
        await payloadFor(t.id),
      );
      expect((await repos.tasks.getById(t.id))!.status, 'done');
    });

    test('AC3: Snooze moves the reminder to now + 1 h', () async {
      final t = await tasks.create(
        title: 'x',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      await reminders.handleAction(
        ReminderActions.snooze,
        await payloadFor(t.id),
      );
      final r = (await reminders.remindersOf(t.id)).single;
      expect(
        DateTime.fromMillisecondsSinceEpoch(r.fireAt),
        now.add(const Duration(minutes: snoozeMinutes)),
      );
      expect(r.fired, isFalse);
      expect((await repos.tasks.getById(t.id))!.status, 'open');
    });

    test('Set renewal task creates a high-priority Vault task', () async {
      final doc = await repos.documents.insert(
        DocumentsCompanion.insert(title: 'Passport (Ali)'),
      );
      final t = await repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Passport expires',
          domain: const Value('vault'),
          sourceDocumentId: Value(doc.id),
          dueAt: Value(DateTime(2026, 12, 6).millisecondsSinceEpoch),
        ),
      );
      await reminders.add(t.id, DateTime(2026, 11, 8, 18));
      final payload = await payloadFor(t.id);
      expect(scheduledReminders(gateway).single.kind, ReminderKind.expiry);

      await reminders.handleAction(ReminderActions.renew, payload);
      final all = await repos.tasks.getAll();
      final renew = all.firstWhere((x) => x.title == 'Renew Passport (Ali)');
      expect((renew.priority, renew.domain), (2, 'vault'));
      expect(localDue(renew), DateTime(2026, 11, 9));
      expect(
        withoutDigest(await sync.resync()),
        isEmpty,
        reason: 'expiry reminder dismissed',
      );
    });

    test('Dismiss marks the reminder fired', () async {
      final t = await tasks.create(
        title: 'x',
        due: DateTime(2026, 11, 8, 16),
        allDay: false,
      );
      await reminders.handleAction(
        ReminderActions.dismiss,
        await payloadFor(t.id),
      );
      expect((await reminders.remindersOf(t.id)).single.fired, isTrue);
    });

    test('stale or garbage payloads are ignored', () async {
      expect(
        await reminders.handleAction(ReminderActions.done, 'junk'),
        isFalse,
      );
      expect(
        await reminders.handleAction(
          ReminderActions.done,
          '{"r":"missing","t":"missing"}',
        ),
        isFalse,
      );
    });
  });

  test('AC6: app lock makes scheduled notifications generic', () async {
    await tasks.create(
      title: 'Call Dr. Ahmed',
      due: DateTime(2026, 11, 8, 16),
      allDay: false,
    );
    final s = (await repos.userSettings.getAll()).single;
    await repos.userSettings.update(
      s.id,
      const UserSettingsCompanion(appLock: Value(true)),
    );
    final planned = withoutDigest(await sync.resync());
    expect(planned.single.title, 'A task is due');
    expect(planned.single.body, isNot(contains('Ahmed')));
  });
}

/// What was scheduled apart from the morning digest (PBI-023), which every
/// resync adds.
List<PlannedNotification> scheduledReminders(FakeGateway g) =>
    g.scheduled.where((p) => p.kind != ReminderKind.digest).toList();

List<PlannedNotification> withoutDigest(List<PlannedNotification> l) =>
    l.where((p) => p.kind != ReminderKind.digest).toList();
