// PBI-031 AC1: how much fits on one 412 × 892 screen with the Flagship look.
// The baseline (before PBI-031) is recorded in the PBI; the targets below
// are the acceptance criteria.
// ignore_for_file: avoid_print
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../widget_test_utils.dart';

Future<void> phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}

/// Widgets keyed `<prefix>…` that are fully visible between the top of the
/// screen and the top of the bottom bar.
int visible(
  WidgetTester tester,
  String prefix, {
  bool Function(String)? where,
}) {
  final navTop = tester.getTopLeft(find.byType(NavigationBar)).dy;
  final keys = find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> &&
        k.value.startsWith(prefix) &&
        (where == null || where(k.value));
  }, skipOffstage: true);
  var n = 0;
  for (final e in keys.evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || !box.attached) continue;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.top >= 0 && r.bottom <= navTop + 0.5) n++;
  }
  return n;
}

Future<void> seed(TestApp app, WidgetTester tester) async {
  final day = DateTime(2026, 11, 8);
  await app.write(tester, () async {
    for (var i = 0; i < 16; i++) {
      await app.repos.tasks.insert(
        TasksCompanion.insert(
          title: 'Task ${i + 1}',
          dueAt: Value(
            DateTime(
              day.year,
              day.month,
              day.day,
              11 + i % 10,
            ).millisecondsSinceEpoch,
          ),
          allDay: const Value(false),
        ),
      );
    }
    for (var i = 0; i < 4; i++) {
      await app.repos.payments.insert(
        PaymentsCompanion.insert(
          title: 'Bill ${i + 1}',
          dueDate: '2026-11-0${i + 5}',
          periodMonth: '2026-11-01',
          amountMinor: const Value(250000),
        ),
      );
    }
    for (var i = 0; i < 14; i++) {
      await app.repos.expenses.insert(
        ExpensesCompanion.insert(
          amountMinor: 50000 + i * 1000,
          spentOn: '2026-11-0${1 + i % 8}',
          note: Value('Expense ${i + 1}'),
        ),
      );
    }
  });
  await settle(tester);
}

void main() {
  appTest('measure what fits on one screen (Flagship)', (tester, app) async {
    await phone(tester);
    await seed(app, tester);

    final home = (
      sections: visible(
        tester,
        'home-',
        where: (k) => const {
          'home-score',
          'home-attention',
          'home-today',
          'home-money',
        }.contains(k),
      ),
      attention: visible(
        tester,
        'attention-',
        where: (k) =>
            !k.contains('swipe') &&
            !k.contains('see-all') &&
            !k.contains('empty'),
      ),
      tasks: visible(tester, 'task-'),
    );

    await openTab(tester, 'Tasks');
    final tasks = visible(tester, 'task-');

    await openTab(tester, 'Vault');
    final vault = visible(
      tester,
      'folder-',
      where: (k) => !k.startsWith('folder-count'),
    );

    await openTab(tester, 'Money');
    final money = visible(tester, 'expense-');

    print(
      'DENSITY home=$home tasks=$tasks vault-folders=$vault '
      'money-expenses=$money',
    );
    density = (home: home, tasks: tasks, vault: vault, money: money);
  });
}

/// The last measurement, for the assertions added with PBI-031.
Object? density;
