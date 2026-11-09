// PBI-033: the pure widget snapshot builder — same data as the dashboard,
// ⚡ ATC first, max 4 lines, privacy mode, and the midnight variant.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/score/domain/life_score.dart';
import 'package:lifeos_app/features/widget/domain/widget_snapshot.dart';

final now = DateTime(2026, 11, 9, 10); // Monday morning
var _n = 0;
String _id() => 'id${_n++}';

Task task({
  String title = 'Task',
  DateTime? due,
  bool allDay = true,
  bool atc = false,
  String status = 'open',
}) => Task(
  id: _id(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  domain: 'mind',
  title: title,
  dueAt: due?.millisecondsSinceEpoch,
  allDay: allDay,
  priority: 1,
  durationMin: 30,
  status: status,
  atcRuleId: atc ? 'rule' : null,
);

Payment payment(
  String due, {
  String title = 'Electricity',
  int? amountMinor = 430000,
  String status = 'upcoming',
  String? taskId,
  int? deletedAt,
}) => Payment(
  id: _id(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  taskId: taskId,
  title: title,
  currency: 'PKR',
  dueDate: due,
  periodMonth: '${due.substring(0, 8)}01',
  status: status,
  amountMinor: amountMinor,
  deletedAt: deletedAt,
);

WidgetSnapshot snap({
  List<Task> tasks = const [],
  List<Payment> payments = const [],
  bool details = true,
  bool rtl = false,
}) => buildWidgetSnapshot(
  tasks: tasks,
  payments: payments,
  documents: const [],
  now: now,
  details: details,
  rtl: rtl,
);

void main() {
  test('⚡ ATC payments come first, capped at 4 lines with "+N more"', () {
    final s = snap(
      tasks: [
        task(title: 'Standup', due: DateTime(2026, 11, 9, 9), allDay: false),
        task(title: 'Gym', due: DateTime(2026, 11, 9, 16), allDay: false),
        task(title: 'Electricity bill', due: DateTime(2026, 11, 9), atc: true),
        task(title: 'Call plumber'),
        task(title: 'Read'),
        task(title: 'Water plants'),
      ],
    );
    final texts = s.today.tasks.map((t) => t.text).toList();
    expect(s.today.tasks, hasLength(4));
    expect(texts.first, '⚡ Electricity bill');
    // Overdue "Standup" (9:00 was before 10:00) rides right behind ⚡,
    // then timed, then anytime.
    expect(texts[1], '9:00 AM · Standup');
    expect(texts[2], '4:00 PM · Gym');
    expect(s.today.more, '+2 more');
    expect(s.today.empty, '');
  });

  test('each line carries its task id for the deep link (AC4)', () {
    final t = task(title: 'Gym', due: DateTime(2026, 11, 9, 16), allDay: false);
    final s = snap(tasks: [t]);
    expect(s.today.tasks.single.id, t.id);
  });

  test('next payment line: "⚡ Electricity ~Rs 4,300 · Thu" (AC1)', () {
    final s = snap(
      payments: [
        payment('2026-11-12', taskId: 't9'),
        payment('2026-11-20', title: 'Internet'), // later: not the next
        payment('2026-11-01', status: 'paid'),
        payment('2026-11-02', status: 'skipped'),
        payment('2026-11-03', deletedAt: 5),
      ],
    );
    expect(s.today.payment, '⚡ Electricity ~Rs 4,300 · Thu');
    expect(s.today.paymentTaskId, 't9');
  });

  test('payment day labels: today, tomorrow, overdue, far date', () {
    expect(
      snap(payments: [payment('2026-11-09')]).today.payment,
      '⚡ Electricity ~Rs 4,300 · Today',
    );
    expect(
      snap(payments: [payment('2026-11-10')]).today.payment,
      '⚡ Electricity ~Rs 4,300 · Tomorrow',
    );
    expect(
      snap(payments: [payment('2026-11-07')]).today.payment,
      '⚡ Electricity ~Rs 4,300 · was due 2 days ago',
    );
    expect(
      snap(payments: [payment('2026-11-25')]).today.payment,
      '⚡ Electricity ~Rs 4,300 · 25 Nov',
    );
  });

  test('a payment without an amount drops the "~" part', () {
    final s = snap(payments: [payment('2026-11-12', amountMinor: null)]);
    expect(s.today.payment, '⚡ Electricity · Thu');
  });

  test('counts: tasks today and payments due by today', () {
    final s = snap(
      tasks: [task(title: 'A'), task(title: 'B')],
      payments: [
        payment('2026-11-09'), // due today
        payment('2026-11-07'), // overdue
        payment('2026-11-20'), // future: not "due"
      ],
    );
    expect(s.today.counts, '2 tasks · 2 due');
    expect(snap().today.counts, 'No tasks');
  });

  test('friendly empty state: "All clear today ✨"', () {
    final s = snap(payments: [payment('2026-11-01', status: 'paid')]);
    expect(s.today.empty, 'All clear today ✨');
    expect(s.today.tasks, isEmpty);
    expect(s.today.payment, '');
  });

  test('details off: only ring and counts, never titles or amounts (AC5)', () {
    final s = snap(
      tasks: [task(title: 'Secret errand')],
      payments: [payment('2026-11-12')],
      details: false,
    );
    expect(s.details, false);
    expect(s.today.tasks, isEmpty);
    expect(s.today.payment, '');
    expect(s.today.paymentTaskId, '');
    expect(s.today.counts, '1 task');
    expect(s.toJsonString().contains('Secret'), false);
    expect(s.toJsonString().contains('4,300'), false);
  });

  test('the score matches the dashboard engine exactly', () {
    final tasks = [task(title: 'Old', due: DateTime(2026, 11, 5))];
    final payments = [payment('2026-11-07')];
    final s = snap(tasks: tasks, payments: payments);
    final expected = computeLifeScore(
      tasks: tasks,
      payments: payments,
      documents: const [],
      now: now,
    ).score;
    expect(s.today.score, expected);
  });

  test('the tomorrow variant drops today-only tasks (midnight swap, AC3)', () {
    final s = snap(
      tasks: [task(title: 'Only today', due: DateTime(2026, 11, 9))],
    );
    expect(s.day, '2026-11-09');
    expect(s.today.tasks, hasLength(1));
    // Due 9 Nov is overdue on 10 Nov — still listed, now as overdue.
    expect(s.tomorrow.tasks, hasLength(1));
    final undated = snap(tasks: [task(title: 'Anytime')]);
    expect(undated.tomorrow.tasks, hasLength(1)); // undated carries over
  });

  test('JSON round-trips with the shape the Android provider reads', () {
    final t = task(title: 'Gym', due: DateTime(2026, 11, 9, 16), allDay: false);
    final s = snap(tasks: [t], payments: [payment('2026-11-12')], rtl: true);
    final json = jsonDecode(s.toJsonString()) as Map<String, dynamic>;
    expect(json['v'], 1);
    expect(json['day'], '2026-11-09');
    expect(json['rtl'], true);
    expect(json['details'], true);
    final today = json['today'] as Map<String, dynamic>;
    expect(today['score'], isA<int>());
    expect(today['counts'], isA<String>());
    expect((today['tasks'] as List).first, {
      'id': t.id,
      'text': '4:00 PM · Gym',
    });
    expect(today['payment'], '⚡ Electricity ~Rs 4,300 · Thu');
    expect(json['tomorrow'], isA<Map<String, dynamic>>());
  });
}
