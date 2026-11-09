// PBI-033: WidgetSync pushes on start, after writes (debounced, AC2) and
// never crashes the app when the widget host fails (AC7).
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/widget/platform/widget_gateway.dart';
import 'package:lifeos_app/features/widget/widget_sync.dart';

import '../../data/db_test_utils.dart';

class RecordingGateway implements WidgetGateway {
  final pushes = <String>[];
  DateTime? lastMidnight;
  bool fail = false;

  @override
  Future<void> push(String snapshotJson, {required DateTime nextMidnight}) async {
    if (fail) throw Exception('launcher gone');
    pushes.add(snapshotJson);
    lastMidnight = nextMidnight;
  }

  @override
  Stream<Uri?> get clicks => const Stream.empty();

  @override
  Future<Uri?> initialUri() async => null;
}

void main() {
  final now = DateTime(2026, 11, 9, 10);
  late AppDatabase db;
  late Repositories repos;
  late RecordingGateway gateway;
  late WidgetSync sync;

  setUp(() async {
    db = memoryDb();
    repos = await openRepos(db);
    gateway = RecordingGateway();
    sync = WidgetSync(
      repos,
      gateway,
      now: () => now,
      debounce: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    await sync.stop();
    await db.close();
  });

  Map<String, dynamic> last() =>
      jsonDecode(gateway.pushes.last) as Map<String, dynamic>;

  test('start pushes once; a batch of writes debounces into one more (AC2)',
      () async {
    await sync.start();
    expect(gateway.pushes, hasLength(1));

    await repos.tasks.insert(TasksCompanion.insert(title: 'One'));
    await repos.tasks.insert(TasksCompanion.insert(title: 'Two'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(gateway.pushes, hasLength(2));
    final today = last()['today'] as Map<String, dynamic>;
    expect((today['tasks'] as List), hasLength(2));
    expect(last()['day'], '2026-11-09');
  });

  test('arms the plugin update for just after midnight (AC3)', () async {
    await sync.start();
    expect(gateway.lastMidnight, DateTime(2026, 11, 10, 0, 5));
  });

  test('"Show details on widget" off strips titles (AC5)', () async {
    await repos.tasks.insert(TasksCompanion.insert(title: 'Secret errand'));
    await repos.userSettings.insert(
      const UserSettingsCompanion(widgetDetails: Value(false)),
    );
    await sync.push();
    final today = last()['today'] as Map<String, dynamic>;
    expect(today['tasks'], isEmpty);
    expect(gateway.pushes.last.contains('Secret'), false);
    expect(today['counts'], '1 task');
  });

  test('a failing widget host never throws and recovers (AC7)', () async {
    gateway.fail = true;
    await sync.push(); // must not throw
    expect(gateway.pushes, isEmpty);
    gateway.fail = false;
    await sync.push();
    expect(gateway.pushes, hasLength(1));
  });

  test('settings changes re-push (language, details)', () async {
    await sync.start();
    final before = gateway.pushes.length;
    await repos.userSettings.insert(
      const UserSettingsCompanion(language: Value('ur')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(gateway.pushes.length, before + 1);
    expect(last()['rtl'], true);
  });
}
