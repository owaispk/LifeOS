// PBI-023 notification diet: digest + timed only (AC1), quiet hours (AC2),
// domain switches (AC3), digest time changes reschedule (AC4).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:lifeos_app/features/reminders/reminder_sync.dart';

import '../../data/db_test_utils.dart';
import '../../fakes.dart';

final now = DateTime(2026, 11, 8, 6); // before the 07:30 digest
var _n = 0;

Task task({
  DateTime? due,
  bool allDay = false,
  String domain = 'mind',
  String? id,
}) => Task(
  id: id ?? 't${_n++}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  domain: domain,
  title: 'Task',
  dueAt: due?.millisecondsSinceEpoch,
  allDay: allDay,
  priority: 1,
  durationMin: 30,
  status: 'open',
);

TaskReminder reminder(Task t, DateTime at) => TaskReminder(
  id: 'r${_n++}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  taskId: t.id,
  fireAt: at.millisecondsSinceEpoch,
  fired: false,
);

void main() {
  group('planner (pure)', () {
    test('AC1: 5 untimed + 1 timed today → exactly 2 notifications', () {
      final untimed = [
        for (var i = 0; i < 5; i++)
          task(due: DateTime(2026, 11, 8), allDay: true),
      ];
      final timed = task(due: DateTime(2026, 11, 8, 16));
      final planned = planNotifications(
        reminders: [reminder(timed, DateTime(2026, 11, 8, 16))],
        tasks: [...untimed, timed],
        payments: const [],
        now: now,
        appLock: false,
        digest: const DigestText('Good morning', 'Life Score 100 · 6 tasks'),
      );
      expect(planned, hasLength(2));
      expect(planned.map((p) => p.kind), [
        ReminderKind.digest,
        ReminderKind.task,
      ]);
      expect(planned.first.fireAt, DateTime(2026, 11, 8, 7, 30));
      expect(planned.first.id, digestNotificationId);
      expect(planned.first.actions, isEmpty);
    });

    test('digest counts the day\'s tasks and bills', () {
      final c = digestCounts(
        tasks: [
          for (var i = 0; i < 5; i++)
            task(due: DateTime(2026, 11, 8), allDay: true),
          task(due: DateTime(2026, 11, 8, 16)),
          task(due: DateTime(2026, 11, 9)), // tomorrow
        ],
        payments: [
          Payment(
            id: 'p',
            userId: 'u',
            updatedAt: 0,
            version: 1,
            title: 'Bill',
            currency: 'PKR',
            dueDate: '2026-11-08',
            periodMonth: '2026-11-01',
            status: 'upcoming',
          ),
        ],
        day: DateTime(2026, 11, 8, 7, 30),
      );
      expect(c, (tasks: 6, bills: 1));
    });

    test('AC2: a 23:00 reminder fires at 07:00 instead', () {
      final t = task(due: DateTime(2026, 11, 9, 10));
      final planned = planNotifications(
        reminders: [reminder(t, DateTime(2026, 11, 8, 23))],
        tasks: [t],
        payments: const [],
        now: now,
        appLock: false,
      );
      expect(planned.single.fireAt, DateTime(2026, 11, 9, 7));
    });

    test('AC2: a task the user timed inside quiet hours fires as set', () {
      final t = task(due: DateTime(2026, 11, 8, 23, 30));
      final planned = planNotifications(
        reminders: [reminder(t, DateTime(2026, 11, 8, 23, 30))],
        tasks: [t],
        payments: const [],
        now: now,
        appLock: false,
      );
      expect(planned.single.fireAt, DateTime(2026, 11, 8, 23, 30));
    });

    test('quiet hours inside one day and after midnight', () {
      const prefs = NotifyPrefs();
      expect(prefs.isQuiet(DateTime(2026, 11, 8, 21, 59)), isFalse);
      expect(prefs.isQuiet(DateTime(2026, 11, 8, 22)), isTrue);
      expect(prefs.isQuiet(DateTime(2026, 11, 9, 3)), isTrue);
      expect(prefs.isQuiet(DateTime(2026, 11, 9, 7)), isFalse);
      expect(
        prefs.quietEndAfter(DateTime(2026, 11, 9, 3)),
        DateTime(2026, 11, 9, 7),
      );
      final day = NotifyPrefs.fromSettings(
        quietStart: '13:00',
        quietEnd: '14:00',
        digestTime: '08:15',
        notifDomains: '{"money":false}',
      );
      expect(day.isQuiet(DateTime(2026, 11, 8, 13, 30)), isTrue);
      expect(day.isQuiet(DateTime(2026, 11, 8, 23)), isFalse);
      expect(day.nextDigest(now), DateTime(2026, 11, 8, 8, 15));
      expect(
        day.nextDigest(DateTime(2026, 11, 8, 9)),
        DateTime(2026, 11, 9, 8, 15),
      );
      expect(day.allows('money'), isFalse);
      expect(day.allows('mind'), isTrue);
    });

    test('AC3: money off silences payment reminders, not the digest', () {
      final bill = task(due: DateTime(2026, 11, 8, 12), domain: 'money');
      final call = task(due: DateTime(2026, 11, 8, 12, 30));
      final payment = Payment(
        id: 'p',
        userId: 'u',
        updatedAt: 0,
        version: 1,
        title: 'Electricity',
        currency: 'PKR',
        dueDate: '2026-11-08',
        periodMonth: '2026-11-01',
        status: 'upcoming',
        taskId: bill.id,
      );
      final planned = planNotifications(
        reminders: [
          reminder(bill, DateTime(2026, 11, 8, 12)),
          reminder(call, DateTime(2026, 11, 8, 12, 30)),
        ],
        tasks: [bill, call],
        payments: [payment],
        now: now,
        appLock: false,
        prefs: const NotifyPrefs(domains: {'money': false}),
        digest: const DigestText('Good morning', '…'),
      );
      expect(planned.map((p) => p.kind), [
        ReminderKind.digest,
        ReminderKind.task,
      ]);
    });
  });

  group('sync (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    late FakeGateway gateway;
    late ReminderSync sync;

    setUp(() async {
      db = memoryDb();
      await openLocalData(db);
      repos = await Repositories.open(db);
      gateway = FakeGateway();
      sync = ReminderSync(
        repos,
        gateway,
        now: () => now,
        debounce: const Duration(milliseconds: 10),
      );
    });
    tearDown(() async {
      await sync.stop();
      await db.close();
    });

    test('AC4: changing the digest time reschedules it right away', () async {
      await sync.start();
      DateTime digestAt() => gateway.scheduled
          .firstWhere((p) => p.kind == ReminderKind.digest)
          .fireAt;
      expect(digestAt(), DateTime(2026, 11, 8, 7, 30));
      final s = (await repos.userSettings.getAll()).first;
      await repos.userSettings.update(
        s.id,
        const UserSettingsCompanion(digestTime: Value('06:45')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(digestAt(), DateTime(2026, 11, 8, 6, 45));
    });

    test('the digest is localised and carries score and counts', () async {
      await repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Call bank',
          dueAt: Value(DateTime(2026, 11, 8, 15).millisecondsSinceEpoch),
          allDay: const Value(false),
        ),
      );
      final planned = await sync.resync();
      final digest = planned.firstWhere((p) => p.kind == ReminderKind.digest);
      expect(digest.title, 'Good morning');
      expect(digest.body, 'Life Score 100 · 1 task · no bills due');
      final s = (await repos.userSettings.getAll()).first;
      await repos.userSettings.update(
        s.id,
        const UserSettingsCompanion(language: Value('ur')),
      );
      final ur = (await sync.resync()).firstWhere(
        (p) => p.kind == ReminderKind.digest,
      );
      expect(ur.title, 'صبح بخیر');
    });
  });
}
