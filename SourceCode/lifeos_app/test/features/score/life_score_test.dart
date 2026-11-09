// PBI-020 Life Score: the pure engine (AC1–AC4), weights asset, snapshots
// (AC5) and the tone rule (AC6).
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/score/data/score_service.dart';
import 'package:lifeos_app/features/score/domain/life_score.dart';

import '../../data/db_test_utils.dart';

final now = DateTime(2026, 11, 8, 10);
final yesterday = DateTime(2026, 11, 7, 18);
var _n = 0;
String _id() => 'id${_n++}';

Task task({
  DateTime? due,
  String status = 'open',
  bool atc = false,
  int? deletedAt,
  String title = 'Task',
}) => Task(
  id: _id(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  domain: 'mind',
  title: title,
  dueAt: (due ?? yesterday).millisecondsSinceEpoch,
  allDay: false,
  priority: 1,
  durationMin: 30,
  status: status,
  atcRuleId: atc ? 'rule' : null,
  deletedAt: deletedAt,
);

Payment payment(
  String due, {
  String status = 'upcoming',
  String title = 'Rent',
}) => Payment(
  id: _id(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  title: title,
  currency: 'PKR',
  dueDate: due,
  periodMonth: '${due.substring(0, 8)}01',
  status: status,
  amountMinor: 100000,
);

Document doc(String? expiry, {int? archivedAt, String title = 'Passport'}) =>
    Document(
      id: _id(),
      userId: 'u',
      updatedAt: 0,
      version: 1,
      title: title,
      docType: 'passport',
      currency: 'PKR',
      favorite: false,
      tags: '[]',
      source: 'scan',
      expiryDate: expiry,
      archivedAt: archivedAt,
    );

LifeScore score({
  List<Task> tasks = const [],
  List<Payment> payments = const [],
  List<Document> documents = const [],
  ScoreWeights weights = ScoreWeights.v1,
  Set<ScoreComponent> unused = unusedInV1,
}) => computeLifeScore(
  tasks: tasks,
  payments: payments,
  documents: documents,
  now: now,
  weights: weights,
  unused: unused,
);

double contributions(LifeScore s) =>
    s.components.fold(0, (a, c) => a + c.contribution);

void main() {
  group('engine (pure)', () {
    test('AC1: a new user with no data scores 100, not 0', () {
      final s = score();
      expect(s.score, 100);
      expect(s.drags, isEmpty);
    });

    test('weights redistribute while Health/People/Balance are unused', () {
      final w = ScoreWeights.v1.effective(unusedInV1);
      expect(w.keys.toSet(), {
        ScoreComponent.tasks,
        ScoreComponent.payments,
        ScoreComponent.documents,
      });
      expect(w[ScoreComponent.tasks], closeTo(42.857, 0.001));
      expect(w[ScoreComponent.payments], closeTo(35.714, 0.001));
      expect(w[ScoreComponent.documents], closeTo(21.429, 0.001));
      expect(w.values.reduce((a, b) => a + b), closeTo(100, 1e-9));
    });

    test('with every module in use, the spec weights apply as-is', () {
      final w = ScoreWeights.v1.effective(const {});
      expect(w[ScoreComponent.tasks], 30);
      expect(w[ScoreComponent.balance], 5);
    });

    test('unused domains never reduce the score', () {
      expect(score(unused: const {}).score, 100);
      expect(score().score, 100);
    });

    test('all of yesterday done → full tasks component', () {
      final s = score(
        tasks: [
          task(status: 'done'),
          task(status: 'done'),
        ],
      );
      expect(s.score, 100);
    });

    test('half of yesterday done → tasks lose half their weight', () {
      final s = score(
        tasks: [
          task(status: 'done'),
          task(),
        ],
      );
      expect(s.score, (100 - 42.857 / 2).round()); // 79
      expect(s.drags.single.kind, DragKind.task);
      expect(s.drags.single.points, -21.4);
    });

    test('ATC payment tasks weigh double', () {
      final open = task(atc: true, title: 'Pay rent');
      final s = score(
        tasks: [
          task(status: 'done'),
          open,
        ],
      );
      // done 1 of weight 3 → ratio ⅓.
      expect(s.components.first.ratio, closeTo(1 / 3, 1e-9));
      expect(s.drags.single.id, open.id);
      expect(s.drags.single.points, -28.6);
    });

    test('only tasks due yesterday count; deleted ones never', () {
      final s = score(
        tasks: [
          task(due: DateTime(2026, 11, 8, 9)), // today
          task(due: DateTime(2026, 11, 6, 9)), // 2 days ago
          task(deletedAt: 1),
        ],
      );
      expect(s.score, 100);
    });

    test('one overdue payment costs ⅓ of the payments weight', () {
      final p = payment('2026-11-01');
      final s = score(payments: [p]);
      expect(s.score, (100 - 35.714 / 3).round()); // 88
      expect(s.drags.single.id, p.id);
      expect(s.drags.single.points, -11.9);
      expect(s.drags.single.detail, 'Was due 1 Nov');
    });

    test('paid, skipped, due-today and future payments never count', () {
      final s = score(
        payments: [
          payment('2026-11-01', status: 'paid'),
          payment('2026-11-01', status: 'skipped'),
          payment('2026-11-08'),
          payment('2026-12-01'),
        ],
      );
      expect(s.score, 100);
    });

    test('3+ overdue payments empty the component but never go below it', () {
      final three = score(
        payments: [
          for (final d in ['01', '02', '03']) payment('2026-11-$d'),
        ],
      );
      expect(three.score, (100 - 35.714).round()); // 64
      final five = score(
        payments: [
          for (final d in ['01', '02', '03', '04', '05']) payment('2026-11-$d'),
        ],
      );
      expect(five.score, three.score);
      expect(five.drags.map((d) => d.points).toSet(), {-7.1});
    });

    test('documents in the 30-day danger window cost ⅓ each', () {
      final s = score(
        documents: [
          doc('2026-12-08'), // exactly 30 days → in
          doc('2026-12-09'), // 31 days → out
          doc('2026-10-01'), // expired → in
          doc('2026-11-20', archivedAt: 1), // archived → out
          doc(null),
        ],
      );
      expect(s.drags, hasLength(2));
      expect(s.score, (100 - 2 * 21.429 / 3).round()); // 86
      expect(s.drags.map((d) => d.detail).toSet(), {
        'Expires in 30 days',
        'Expired 38 days ago',
      });
    });

    test('bounds: everything wrong scores 0, never negative', () {
      final s = score(
        tasks: [task(), task(atc: true)],
        payments: [
          for (final d in ['01', '02', '03', '04']) payment('2026-11-$d'),
        ],
        documents: [for (var i = 0; i < 4; i++) doc('2026-10-0${i + 1}')],
      );
      expect(s.score, 0);
      expect(s.triage, isTrue);
    });

    test('AC3: every drag points at a real id and costs points', () {
      final t = task();
      final p = payment('2026-11-01');
      final d = doc('2026-11-15');
      final s = score(tasks: [t], payments: [p], documents: [d]);
      expect(s.drags.map((x) => x.id).toSet(), {t.id, p.id, d.id});
      expect(s.drags.every((x) => x.points < 0), isTrue);
      expect(
        s.drags.map((x) => x.points).toList(),
        [...s.drags.map((x) => x.points)]..sort(),
        reason: 'most costly first',
      );
    });

    test('AC4: contributions add up to the displayed score (±1)', () {
      for (final s in [
        score(),
        score(
          tasks: [
            task(),
            task(status: 'done'),
            task(atc: true),
          ],
        ),
        score(
          payments: [payment('2026-11-02')],
          documents: [doc('2026-11-30')],
        ),
        score(
          tasks: [task()],
          payments: [payment('2026-11-01'), payment('2026-11-03')],
          documents: [doc('2026-10-01')],
        ),
      ]) {
        expect((contributions(s) - s.score).abs(), lessThanOrEqualTo(1));
        final drags = s.drags.fold<double>(0, (a, d) => a + d.points);
        expect((100 + drags - s.score).abs(), lessThanOrEqualTo(1));
      }
    });

    test('ring colour bands and labels: <40, 40–69, ≥70', () {
      expect(scoreLabel(39), 'Heavy week');
      expect(scoreLabel(40), 'A few things need you');
      expect(scoreLabel(69), 'A few things need you');
      expect(scoreLabel(70), 'Doing well');
    });

    test('snapshot JSON carries components and drags', () {
      final p = payment('2026-11-01');
      final s = score(payments: [p]);
      final drags = jsonDecode(s.dragsJson()) as List;
      expect(drags.single, {
        'kind': 'overdue_payment',
        'id': p.id,
        'title': 'Rent',
        'points': -11.9,
      });
      final comps = jsonDecode(s.componentsJson()) as Map<String, dynamic>;
      expect(comps.keys, ['tasks', 'payments', 'documents']);
    });

    test('the shipped weights file equals the built-in v1 weights', () {
      final asset = ScoreWeights.fromJson(
        File('assets/score_weights.json').readAsStringSync(),
      );
      expect(asset.version, ScoreWeights.v1.version);
      expect(asset.weights, ScoreWeights.v1.weights);
    });

    test('last 7 days for the sparkline, today live', () {
      ScoreSnapshot snap(String day, int score) => ScoreSnapshot(
        id: day,
        userId: 'u',
        updatedAt: 0,
        version: 1,
        day: day,
        score: score,
        components: '{}',
        drags: '[]',
      );
      expect(
        lastDays(
          [
            snap('2026-11-02', 70),
            snap('2026-11-07', 80),
            snap('2026-11-08', 1),
          ],
          now,
          todayScore: 90,
        ),
        [70, null, null, null, null, 80, 90],
      );
    });
  });

  group('snapshots (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    var clock = now;

    setUp(() async {
      db = memoryDb();
      clock = now;
      await openLocalData(db);
      repos = await Repositories.open(
        db,
        clock: () => clock.millisecondsSinceEpoch,
      );
    });
    tearDown(() => db.close());

    test('AC5: computing twice on one day upserts one row', () async {
      final service = ScoreService(repos, now: () => clock);
      await service.refresh();
      await repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'Rent',
          dueDate: '2026-11-01',
          periodMonth: '2026-11-01',
          amountMinor: const Value(100000),
        ),
      );
      final second = await service.refresh();
      final rows = await repos.scoreSnapshots.getAll();
      expect(rows, hasLength(1));
      expect((rows.single.day, rows.single.score), ('2026-11-08', 88));
      expect(second.delta, isNull, reason: 'no snapshot yesterday');
    });

    test('delta compares with yesterday\'s snapshot', () async {
      clock = DateTime(2026, 11, 7, 10);
      await ScoreService(repos, now: () => clock).refresh(); // 100
      clock = now;
      await repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'Rent',
          dueDate: '2026-11-01',
          periodMonth: '2026-11-01',
        ),
      );
      final today = await ScoreService(repos, now: () => clock).refresh();
      expect(today.score.score, 88);
      expect(today.delta, -12);
      expect(await repos.scoreSnapshots.getAll(), hasLength(2));
    });
  });

  test('AC6: no guilt words in Score or Home copy', () {
    final banned = RegExp(
      r'\b(failed|fail|failure|missed|lazy|behind|shame|bad|should have)\b',
      caseSensitive: false,
    );
    final strings = RegExp(
      r"'([^'\\]|\\.)*'|"
      r'"([^"\\]|\\.)*"',
    );
    final offenders = <String>[];
    for (final dir in ['lib/features/score', 'lib/features/home']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          if (line.trimLeft().startsWith('//')) continue;
          for (final m in strings.allMatches(line)) {
            if (banned.hasMatch(m[0]!)) offenders.add('${f.path}: ${m[0]}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
