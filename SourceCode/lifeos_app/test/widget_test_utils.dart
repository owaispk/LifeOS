import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/app.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/tasks/tasks_providers.dart';

import 'data/db_test_utils.dart';

/// Sunday 8 Nov 2026, 10:00 local — the fixed "now" for widget tests.
final testNow = DateTime(2026, 11, 8, 10);

/// A seeded in-memory database plus the app, wired together.
class TestApp {
  TestApp(this.db, this.repos);
  final AppDatabase db;
  final Repositories repos;

  static Future<TestApp> pump(WidgetTester tester) async {
    final db = memoryDb();
    final repos = await tester.runAsync(() => openLocalData(db));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoriesProvider.overrideWithValue(repos!),
          nowProvider.overrideWithValue(() => testNow),
        ],
        child: const LifeOsApp(),
      ),
    );
    await tester.pumpAndSettle();
    return TestApp(db, repos);
  }

  /// Unmounts the app (cancelling Drift stream queries), flushes the
  /// clean-up timers Drift schedules for them, and closes the database.
  /// Must run inside the test body: pending timers fail the test before
  /// tear-downs run.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    await tester.runAsync(db.close);
  }

  /// Runs real database work outside the fake-async zone, then lets the
  /// UI catch up with the stream updates.
  Future<T> write<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    await tester.pumpAndSettle();
    return result as T;
  }
}

/// A widget test with a fresh seeded app; always cleans up, even on failure.
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, TestApp app) body,
) {
  testWidgets(description, (tester) async {
    final app = await TestApp.pump(tester);
    try {
      await body(tester, app);
    } finally {
      await app.close(tester);
    }
  });
}

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(navItem(label));
  await tester.pumpAndSettle();
}

/// Lets a UI-triggered database write reach the screen.
///
/// The test database lives in the real async zone (it is opened with
/// `runAsync`), so Drift delivers stream updates there; give the real event
/// loop a moment, then let the fake-async UI catch up.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }
}

/// A tall, phone-like viewport (logical 412×1600) so long lists build all
/// their rows. Restored automatically after the test.
Future<void> useTallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
}
