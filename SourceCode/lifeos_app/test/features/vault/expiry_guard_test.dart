// PBI-008 Expiry Guard: ladder (AC1, AC7), reconcile on a real DB
// (AC2–AC5), renewal (AC6).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/capture/data/capture_service.dart';
import 'package:lifeos_app/features/reminders/domain/reminder_planner.dart';
import 'package:lifeos_app/features/vault/data/expiry_guard.dart';
import 'package:lifeos_app/features/vault/data/search_service.dart';
import 'package:lifeos_app/features/vault/domain/expiry_ladder.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';
import '../capture/image_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 8, 10); // a Sunday

  group('ladder (pure)', () {
    test('defaults by type, with overrides', () {
      expect(ladderFor('passport', null), [180, 90, 30]);
      expect(ladderFor('visa', null), [180, 90, 30]);
      expect(ladderFor('bill', null), [3, 0, -1]);
      expect(ladderFor('cnic', null), [90, 30, 7, 1]);
      expect(ladderFor('cnic', '[60,14]'), [60, 14]);
      expect(ladderFor('cnic', 'garbage'), [90, 30, 7, 1]);
    });

    test('AC1: a passport 200 days out gets exactly 180/90/30', () {
      final expiry = DateTime(2027, 5, 27); // 200 days after 8 Nov 2026
      final alerts = futureAlerts(expiry, ladderFor('passport', null), now);
      expect(alerts, [
        DateTime(2026, 11, 28, 9),
        DateTime(2027, 2, 26, 9),
        DateTime(2027, 4, 27, 9),
      ]);
    });

    test('AC7: month ends and leap years', () {
      expect(alertAt(DateTime(2028, 3, 1), 1), DateTime(2028, 2, 29, 9));
      expect(alertAt(DateTime(2027, 3, 1), 1), DateTime(2027, 2, 28, 9));
      expect(alertAt(DateTime(2027, 1, 31), 30), DateTime(2027, 1, 1, 9));
      expect(alertAt(DateTime(2027, 3, 31), 30), DateTime(2027, 3, 1, 9));
      expect(alertAt(DateTime(2026, 12, 5), 7), DateTime(2026, 11, 28, 9));
      expect(alertAt(DateTime(2026, 11, 20), -1), DateTime(2026, 11, 21, 9));
    });

    test('only future alerts; past ones drop off', () {
      // Expires in 20 days: 90 and 30 already passed.
      final alerts = futureAlerts(DateTime(2026, 11, 28), [90, 30, 7, 1], now);
      expect(alerts, [DateTime(2026, 11, 21, 9), DateTime(2026, 11, 27, 9)]);
    });

    test('weekly nudge: next Sunday 18:00, strictly later', () {
      expect(weeklyNudge(now), DateTime(2026, 11, 8, 18)); // Sun 10:00
      expect(
        weeklyNudge(DateTime(2026, 11, 8, 19)),
        DateTime(2026, 11, 15, 18),
      );
      expect(
        weeklyNudge(DateTime(2026, 11, 11, 9)),
        DateTime(2026, 11, 15, 18),
      );
    });
  });

  group('guard (real database)', () {
    late AppDatabase db;
    late Repositories repos;
    late ExpiryGuard guard;

    setUp(() async {
      db = memoryDb();
      await openLocalData(db);
      repos = await Repositories.open(
        db,
        clock: () => now.millisecondsSinceEpoch,
      );
      guard = ExpiryGuard(repos, now: () => now);
    });
    tearDown(() => db.close());

    Future<Document> doc(
      String title, {
      String type = 'passport',
      String? expiry,
    }) => repos.documents.insert(
      DocumentsCompanion.insert(
        title: title,
        docType: Value(type),
        expiryDate: Value(expiry),
      ),
    );

    Future<List<DateTime>> remindersOf(String docId) async {
      final task = await guard.renewalTaskFor(docId);
      if (task == null) return const [];
      final r = await repos.taskReminders.getWhere(
        (x) => x.taskId.equals(task.id),
      );
      return [for (final x in r) DateTime.fromMillisecondsSinceEpoch(x.fireAt)]
        ..sort();
    }

    test('AC1: renewal task + exactly 3 reminders for a passport', () async {
      final d = await doc('Passport (Ali)', expiry: '2027-05-27');
      await guard.reconcile();
      final task = (await guard.renewalTaskFor(d.id))!;
      expect(
        (task.title, task.domain, task.priority),
        ('Renew Passport (Ali)', 'vault', 2),
      );
      expect(await remindersOf(d.id), hasLength(3));
    });

    test(
      'AC2: changing the date replaces reminders; reruns add nothing',
      () async {
        final d = await doc('Passport', expiry: '2027-05-27');
        await guard.reconcile();
        await repos.documents.update(
          d.id,
          const DocumentsCompanion(expiryDate: Value('2027-01-31')),
        );
        await guard.reconcile();
        await guard.reconcile();
        // New expiry 31 Jan 2027: 180 and 90 days before are already past,
        // so only the 30-day alert remains — the old three are gone.
        expect(await remindersOf(d.id), [DateTime(2027, 1, 1, 9)]);
        final tasks = await repos.tasks.getWhere(
          (t) => t.sourceDocumentId.equals(d.id),
        );
        expect(tasks, hasLength(1), reason: 'one renewal task, moved');
        expect(
          DateTime.fromMillisecondsSinceEpoch(tasks.single.dueAt!),
          DateTime(2027, 1, 31),
        );
      },
    );

    test('clearing the date, archiving or deleting removes the task', () async {
      final a = await doc('A', expiry: '2027-05-27');
      final b = await doc('B', expiry: '2027-05-27');
      final c = await doc('C', expiry: '2027-05-27');
      await guard.reconcile();
      await repos.documents.update(
        a.id,
        const DocumentsCompanion(expiryDate: Value(null)),
      );
      await repos.documents.update(
        b.id,
        DocumentsCompanion(archivedAt: Value(now.millisecondsSinceEpoch)),
      );
      await repos.documents.softDelete(c.id);
      await guard.reconcile();
      for (final d in [a, b, c]) {
        expect(await guard.renewalTaskFor(d.id), isNull, reason: d.title);
      }
    });

    test('AC4: expired documents share one weekly nudge', () async {
      final old1 = await doc(
        'Old licence',
        type: 'license',
        expiry: '2026-09-01',
      );
      final old2 = await doc('Old CNIC', type: 'cnic', expiry: '2026-10-01');
      await guard.reconcile();
      expect(await remindersOf(old1.id), [DateTime(2026, 11, 8, 18)]);
      expect(await remindersOf(old2.id), isEmpty);
    });

    test('AC5: the notification never names the document', () async {
      await doc('Passport AB1234567 (Ali Khan)', expiry: '2027-05-27');
      await guard.reconcile();
      final planned = planNotifications(
        reminders: await repos.taskReminders.getAll(),
        tasks: await repos.tasks.getAll(),
        payments: const [],
        now: now,
        appLock: false,
      );
      expect(planned, hasLength(3));
      for (final n in planned) {
        expect(n.kind, ReminderKind.expiry);
        expect(n.title, 'A document expires soon');
        expect('${n.title} ${n.body}', isNot(contains('AB1234567')));
        expect('${n.title} ${n.body}', isNot(contains('Ali')));
      }
    });

    test(
      'AC6: renewing archives and links the old one; both searchable',
      () async {
        final tmp = await Directory.systemTemp.createTemp('lifeos_renew_');
        addTearDown(() => tmp.delete(recursive: true));
        final old = await doc('Passport 2017', expiry: '2026-12-01');
        await guard.reconcile();
        final page = File(p.join(tmp.path, 'n.jpg'))
          ..writeAsBytesSync(jpeg(fakeDocument(width: 200, height: 260)));
        final fresh = await CaptureService(repos, tmp, now: () => now).save(
          CaptureDraft.scan([page.path]),
          FilingDetails(
            title: 'Passport 2027',
            docType: 'passport',
            renewsDocumentId: old.id,
            fields: const {'expiry_date': '2037-01-01'},
          ),
        );
        final archived = (await repos.documents.getById(old.id))!;
        expect(archived.archivedAt, isNotNull);
        expect(archived.renewedById, fresh.id);
        await guard.reconcile();
        expect(await guard.renewalTaskFor(old.id), isNull);
        expect(await guard.renewalTaskFor(fresh.id), isNotNull);

        final hits = await SearchService(
          db,
          now: () => now,
        ).search('passport', noFilters);
        expect(hits.map((h) => h.document.title).toSet(), {
          'Passport 2017',
          'Passport 2027',
        });
      },
    );
  });
}
