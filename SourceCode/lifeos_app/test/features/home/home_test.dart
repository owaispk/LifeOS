// PBI-021 Home dashboard (pure rules + widget) and the PBI-020 Life Score
// detail screen.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/home/domain/attention.dart';

import '../../widget_test_utils.dart';

var _n = 0;

Payment pay(String due, {String status = 'upcoming', int? amount = 100000}) =>
    Payment(
      id: 'p${_n++}',
      userId: 'u',
      updatedAt: 0,
      version: 1,
      title: 'Pay $due',
      currency: 'PKR',
      dueDate: due,
      periodMonth: '${due.substring(0, 8)}01',
      status: status,
      amountMinor: amount,
    );

Document expiring(String expiry, {int? archivedAt}) => Document(
  id: 'd${_n++}',
  userId: 'u',
  updatedAt: 0,
  version: 1,
  title: 'Doc $expiry',
  docType: 'passport',
  currency: 'PKR',
  favorite: false,
  tags: '[]',
  source: 'scan',
  expiryDate: expiry,
  archivedAt: archivedAt,
);

/// Inserts a payment (and its task) the app shows.
Future<Payment> addPayment(
  TestApp app,
  WidgetTester tester,
  String title,
  String due, {
  int? amount = 485000,
}) => app.write(tester, () async {
  final t = await app.repos.tasks.insert(
    TasksCompanion.insert(
      title: title,
      domain: const Value('money'),
      dueAt: Value(DateTime.parse(due).millisecondsSinceEpoch),
    ),
  );
  return app.repos.payments.insert(
    PaymentsCompanion.insert(
      title: title,
      dueDate: due,
      periodMonth: '${due.substring(0, 8)}01',
      taskId: Value(t.id),
      amountMinor: Value(amount),
    ),
  );
});

Future<Document> addDoc(
  TestApp app,
  WidgetTester tester,
  String title,
  String expiry,
) => app.write(
  tester,
  () => app.repos.documents.insert(
    DocumentsCompanion.insert(title: title, expiryDate: Value(expiry)),
  ),
);

List<String> attentionTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('attention-'),
      ),
    )
    .map((t) => (t.title! as Text).data!)
    .toList();

double topOf(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;

void main() {
  final now = DateTime(2026, 11, 8, 10); // Sunday

  group('rules (pure)', () {
    test('AC1: due-by-tomorrow payments and 30-day documents, by urgency', () {
      final items = attentionItems(
        payments: [
          pay('2026-11-09'), // tomorrow
          pay('2026-11-05'), // overdue
          pay('2026-11-10'), // 2 days → not yet
          pay('2026-11-01', status: 'paid'),
        ],
        documents: [
          expiring('2026-11-09'), // tomorrow, ties with the payment
          expiring('2026-12-08'), // 30 days
          expiring('2026-12-09'), // 31 days → out
          expiring('2026-11-01', archivedAt: 1),
        ],
        now: now,
      );
      expect(items.map((i) => (i.kind.name, i.daysLeft)).toList(), [
        ('payment', -3),
        ('payment', 1),
        ('document', 1),
        ('document', 30),
      ]);
      expect(items.first.when, 'was due 3 days ago');
      expect(items[1].when, 'due tomorrow');
      expect(items[2].when, 'expires tomorrow');
      expect(items.last.urgent, isFalse);
    });

    test('AC3: the week strip sums unpaid payments due Mon–Sun', () {
      // 8 Nov 2026 is a Sunday: the week is Mon 2 – Sun 8 Nov.
      expect(weekOf(now), (
        from: DateTime(2026, 11, 2),
        to: DateTime(2026, 11, 8),
      ));
      final total = weekPaymentsMinor([
        pay('2026-11-02', amount: 1000000), // Mon ✓
        pay('2026-11-08', amount: 450000), // Sun ✓
        pay('2026-11-05', amount: null), // unknown → left out
        pay('2026-11-06', amount: 200000, status: 'paid'), // paid ✗
        pay('2026-11-01', amount: 999900), // last week ✗
        pay('2026-11-09', amount: 999900), // next week ✗
      ], now);
      expect(total, 1450000);
      expect(weekOf(DateTime(2026, 11, 2)).from, DateTime(2026, 11, 2));
    });

    test('greeting uses the name once it is set', () {
      Person p(String name) => Person(
        id: 'x',
        userId: 'u',
        updatedAt: 0,
        version: 1,
        name: name,
        relation: 'self',
        sortOrder: 0,
      );
      expect(greeting(null), 'Salam 👋');
      expect(greeting(p('Me')), 'Salam 👋');
      expect(greeting(p('Owais')), 'Salam, Owais 👋');
    });
  });

  appTest('AC4: a new user sees prompts, not empty sections', (
    tester,
    app,
  ) async {
    expect(find.byKey(const ValueKey('home-prompts')), findsOneWidget);
    expect(find.text('Scan your first document 📸'), findsOneWidget);
    expect(find.text('Add what you pay regularly ⚡'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-attention')), findsNothing);
    // AC1 (PBI-020): nothing to punish → 100.
    expect(find.text('100'), findsOneWidget);
    expect(find.text('All clear today ✓'), findsOneWidget);
  });

  appTest('AC6/AC1: section order and the 3-item cap; See all lists all', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    await addPayment(app, tester, 'Electricity bill', '2026-11-09');
    await addPayment(app, tester, 'Rent', '2026-11-01');
    await addDoc(app, tester, 'Passport (Ali)', '2026-12-06');
    await addDoc(app, tester, 'Visa', '2026-11-20');
    await app.write(
      tester,
      () => app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Call electrician',
          dueAt: Value(DateTime(2026, 11, 8, 16).millisecondsSinceEpoch),
          allDay: const Value(false),
        ),
      ),
    );
    await settle(tester);

    expect(attentionTitles(tester), ['Rent', 'Electricity bill', 'Visa']);
    expect(find.text('See all (4)'), findsOneWidget);
    expect(find.text('4 things need attention'), findsOneWidget);

    // Order: score → attention → today → money.
    final order = [
      topOf(tester, 'home-score'),
      topOf(tester, 'home-attention'),
      topOf(tester, 'home-today'),
      topOf(tester, 'home-money'),
    ];
    expect(order, [...order]..sort());
    expect(find.text('Call electrician'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('attention-see-all')));
    await tester.pumpAndSettle();
    expect(attentionTitles(tester), [
      'Rent',
      'Electricity bill',
      'Visa',
      'Passport (Ali)',
    ]);
  });

  appTest('AC3: the money strip shows this week\'s unpaid payments', (
    tester,
    app,
  ) async {
    await addPayment(app, tester, 'Rent', '2026-11-03', amount: 1000000);
    await addPayment(app, tester, 'Internet', '2026-11-07', amount: 450000);
    await addPayment(app, tester, 'Fee', '2026-11-12', amount: 900000);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-money')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rs 14,500 in payments this week'), findsOneWidget);
  });

  appTest('AC2: swiping a payment right opens the completion chain', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final p = await addPayment(app, tester, 'Electricity bill', '2026-11-09');
    await settle(tester);
    await tester.drag(
      find.byKey(ValueKey('attention-${p.id}')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    // The M2 sheet (PBI-016): skip the receipt → paid.
    await tester.tap(find.byKey(const ValueKey('paid-skip')));
    await settle(tester);
    final stored = await tester.runAsync(
      () => app.repos.payments.getById(p.id),
    );
    expect(stored!.status, 'paid');
    final expenses = await tester.runAsync(app.repos.expenses.getAll);
    expect(expenses!.single.amountMinor, 485000);
    expect(find.byKey(ValueKey('attention-${p.id}')), findsNothing);
  });

  appTest('AC5: pull-to-refresh writes the snapshot and shows the delta', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    // Yesterday's snapshot was 100; one overdue payment today → 88, ↓12.
    await app.write(
      tester,
      () => app.repos.scoreSnapshots.insert(
        ScoreSnapshotsCompanion.insert(
          day: '2026-11-07',
          score: 100,
          components: '{}',
          drags: '[]',
        ),
      ),
    );
    await addPayment(app, tester, 'Rent', '2026-11-01');
    await settle(tester);
    await tester.fling(
      find.byKey(const ValueKey('home-list')),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('↓12'), findsOneWidget);
    final snaps = await tester.runAsync(app.repos.scoreSnapshots.getAll);
    final today = snaps!.where((s) => s.day == '2026-11-08').single;
    expect(today.score, 88);
  });

  appTest('PBI-020: the score detail lists drags with one-tap fixes', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    final task = await app.write(
      tester,
      () => app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Review CV',
          dueAt: Value(DateTime(2026, 11, 7, 9).millisecondsSinceEpoch),
        ),
      ),
    );
    await addPayment(app, tester, 'Rent', '2026-11-01');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-score')));
    await tester.pumpAndSettle();

    expect(find.text('What would lift it'), findsOneWidget);
    expect(find.byKey(ValueKey('drag-${task.id}')), findsOneWidget);
    for (final c in ['tasks', 'payments', 'documents']) {
      expect(find.byKey(ValueKey('component-$c')), findsOneWidget);
    }
    // 100 − 42.9 (task) − 11.9 (payment) = 45.
    expect(find.text('45'), findsWidgets);
    expect(find.text('A few things need you'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('fix-${task.id}')));
    await settle(tester);
    expect(find.byKey(ValueKey('drag-${task.id}')), findsNothing);
    expect(find.text('88'), findsWidgets);
  });

  appTest('PBI-020: below 40 the detail switches to triage mode', (
    tester,
    app,
  ) async {
    await useTallScreen(tester);
    for (final d in ['01', '02', '03', '04']) {
      await addPayment(app, tester, 'Bill $d', '2026-11-$d');
    }
    for (final d in ['01', '02', '03']) {
      await addDoc(app, tester, 'Doc $d', '2026-10-$d');
    }
    // Payments and documents alone leave 43; yesterday's open task → 0.
    await app.write(
      tester,
      () => app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Review CV',
          dueAt: Value(DateTime(2026, 11, 7, 9).millisecondsSinceEpoch),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-score')));
    await tester.pumpAndSettle();
    expect(
      find.text('Heavy week? Here are the 3 highest-impact items'),
      findsOneWidget,
    );
    expect(find.byWidgetPredicate(_isDrag), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('drags-show-all')));
    await tester.pumpAndSettle();
    // The list is lazy: more than 3 are built, the button is gone and the
    // last (cheapest) item is reachable.
    expect(
      tester.widgetList(find.byWidgetPredicate(_isDrag)).length,
      greaterThan(3),
    );
    expect(find.byKey(const ValueKey('drags-show-all')), findsNothing);
    expect(find.text('What would lift it'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Doc 03'), 300);
    expect(find.text('Doc 03'), findsOneWidget);
  });
}

bool _isDrag(Widget w) =>
    w is Card &&
    w.key is ValueKey<String> &&
    (w.key! as ValueKey<String>).value.startsWith('drag-');
