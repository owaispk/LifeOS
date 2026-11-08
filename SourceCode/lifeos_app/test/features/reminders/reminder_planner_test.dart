// PBI-012: what gets scheduled — pure planner (AC5, AC6) and helpers.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';

final now = DateTime(2026, 11, 8, 10);

Task task(
  String id, {
  String title = 'Call electrician',
  String status = 'open',
  int? deletedAt,
  String? atc,
  String domain = 'mind',
  String? sourceDocumentId,
  DateTime? due,
}) => Task(
  id: id,
  userId: 'u',
  updatedAt: 0,
  version: 1,
  deletedAt: deletedAt,
  domain: domain,
  title: title,
  dueAt: (due ?? DateTime(2026, 11, 8, 16)).millisecondsSinceEpoch,
  allDay: false,
  priority: 1,
  durationMin: 30,
  status: status,
  atcRuleId: atc,
  sourceDocumentId: sourceDocumentId,
);

var _r = 0;
TaskReminder reminder(
  String taskId,
  DateTime at, {
  bool fired = false,
  int? deletedAt,
}) => TaskReminder(
  id: 'r${(_r++).toString().padLeft(4, '0')}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  deletedAt: deletedAt,
  taskId: taskId,
  fireAt: at.millisecondsSinceEpoch,
  fired: fired,
);

Payment payment(
  String taskId, {
  int? amount = 485000,
  String status = 'upcoming',
}) => Payment(
  id: 'p-$taskId',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  taskId: taskId,
  title: 'Electricity',
  amountMinor: amount,
  currency: 'PKR',
  dueDate: '2026-11-09',
  periodMonth: '2026-11-01',
  status: status,
);

List<PlannedNotification> plan({
  required List<TaskReminder> reminders,
  required List<Task> tasks,
  List<Payment> payments = const [],
  bool appLock = false,
  int limit = maxScheduled,
}) => planNotifications(
  reminders: reminders,
  tasks: tasks,
  payments: payments,
  now: now,
  appLock: appLock,
  limit: limit,
);

void main() {
  test('notification ids are stable, positive 31-bit ints', () {
    final a = notificationIdFor('0194f1c2-aaaa-7bbb-8ccc-1234567890ab');
    expect(a, notificationIdFor('0194f1c2-aaaa-7bbb-8ccc-1234567890ab'));
    expect(a, inInclusiveRange(0, 0x7FFFFFFF));
    expect(notificationIdFor('0194f1c2-aaaa-7bbb-8ccc-1234567890ac'), isNot(a));
  });

  test('only future, unfired, live reminders on open tasks are planned', () {
    final open = task('t-open');
    final p = plan(
      tasks: [
        open,
        task('t-done', status: 'done'),
        task('t-skipped', status: 'skipped'),
        task('t-deleted', deletedAt: 1),
      ],
      reminders: [
        reminder('t-open', DateTime(2026, 11, 8, 16)), // ✓
        reminder('t-open', DateTime(2026, 11, 8, 9)), // past
        reminder('t-open', DateTime(2026, 11, 8, 17), fired: true),
        reminder('t-open', DateTime(2026, 11, 8, 18), deletedAt: 1),
        reminder('t-done', DateTime(2026, 11, 8, 16)), // AC5: completed
        reminder('t-skipped', DateTime(2026, 11, 8, 16)),
        reminder('t-deleted', DateTime(2026, 11, 8, 16)), // AC5: deleted
        reminder('t-missing', DateTime(2026, 11, 8, 16)),
      ],
    );
    expect(p, hasLength(1));
    expect(p.single.taskId, 't-open');
    expect(p.single.kind, ReminderKind.task);
    expect(p.single.actions, [ReminderActions.done, ReminderActions.snooze]);
    expect(p.single.title, 'Call electrician');
    expect(p.single.body, 'Due 4:00 PM');
  });

  test('soonest first, capped for the iOS 64-pending limit', () {
    final t = task('t');
    final reminders = [
      for (var i = 70; i > 0; i--) reminder('t', now.add(Duration(minutes: i))),
    ];
    final p = plan(tasks: [t], reminders: reminders);
    expect(p, hasLength(60));
    expect(p.first.fireAt, now.add(const Duration(minutes: 1)));
    expect(p.last.fireAt, now.add(const Duration(minutes: 60)));
  });

  test('payment tasks get Paid ✓ / Snooze and show the amount', () {
    final p = plan(
      tasks: [task('t', title: 'Electricity bill', atc: 'rule')],
      payments: [payment('t')],
      reminders: [reminder('t', DateTime(2026, 11, 8, 18))],
    ).single;
    expect(p.kind, ReminderKind.payment);
    expect(p.actions, [ReminderActions.paid, ReminderActions.snooze]);
    expect(p.body, 'Rs 4,850 · due 4:00 PM');
  });

  test('a paid payment is just a task again', () {
    final p = plan(
      tasks: [task('t', atc: 'rule')],
      payments: [payment('t', status: 'paid')],
      reminders: [reminder('t', DateTime(2026, 11, 8, 18))],
    ).single;
    expect(p.kind, ReminderKind.task);
  });

  test('expiry reminders are always generic (decoy safety)', () {
    final p = plan(
      tasks: [
        task(
          't',
          title: 'Passport AB1234567 expires',
          domain: 'vault',
          sourceDocumentId: 'doc',
        ),
      ],
      reminders: [reminder('t', DateTime(2026, 11, 8, 18))],
    ).single;
    expect(p.kind, ReminderKind.expiry);
    expect(p.actions, [ReminderActions.renew, ReminderActions.dismiss]);
    expect('${p.title} ${p.body}', isNot(contains('AB1234567')));
    expect(p.title, 'A document expires soon');
  });

  test('AC6: with app lock on, no amount, name or number is shown', () {
    final planned = plan(
      appLock: true,
      tasks: [
        task('t1', title: 'Pay Ali school fee', atc: 'rule'),
        task('t2', title: 'Call Dr. Ahmed about MRI'),
      ],
      payments: [payment('t1', amount: 1200000)],
      reminders: [
        reminder('t1', DateTime(2026, 11, 8, 18)),
        reminder('t2', DateTime(2026, 11, 8, 19)),
      ],
    );
    expect(planned.map((p) => p.title), ['A payment is due', 'A task is due']);
    for (final p in planned) {
      final text = '${p.title} ${p.body}';
      for (final secret in ['Ali', 'Ahmed', 'MRI', '12,000', 'Rs']) {
        expect(text, isNot(contains(secret)));
      }
    }
  });

  test('payload round-trips and garbage is ignored', () {
    final p = plan(
      tasks: [task('t')],
      reminders: [reminder('t', DateTime(2026, 11, 8, 18))],
    ).single;
    final parsed = PlannedNotification.parsePayload(p.payload)!;
    expect((parsed.reminderId, parsed.taskId), (p.reminderId, 't'));
    expect(PlannedNotification.parsePayload('nope'), isNull);
    expect(PlannedNotification.parsePayload(null), isNull);
  });

  test('reminder offsets', () {
    final due = DateTime(2026, 11, 9, 9);
    expect(applyOffset(due, ReminderOffset.atDue), due);
    expect(
      applyOffset(due, ReminderOffset.min10),
      DateTime(2026, 11, 9, 8, 50),
    );
    expect(applyOffset(due, ReminderOffset.hour1), DateTime(2026, 11, 9, 8));
    expect(applyOffset(due, ReminderOffset.day1), DateTime(2026, 11, 8, 9));
    expect(
      applyOffset(DateTime(2026, 12, 1, 9), ReminderOffset.day1),
      DateTime(2026, 11, 30, 9),
    );
  });
}
