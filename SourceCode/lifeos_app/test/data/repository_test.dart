// PBI-002 AC2–AC4: CRUD + soft delete through every repository, with one
// outbox entry per write and optimistic version/updated_at bookkeeping.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/db/tables.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/data/repositories/sync_repository.dart';

import 'db_test_utils.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late Repositories r;

  setUp(() async {
    db = memoryDb();
    clock = FakeClock();
    r = await openRepos(db, clock);
  });
  tearDown(() => db.close());

  /// Runs insert → read → update → soft delete on one repository and checks
  /// every PBI-002 rule along the way.
  Future<void> exercise<T extends SyncColumns, D extends DataClass>(
    SyncRepository<T, D> repo, {
    required Insertable<D> create,
    required Insertable<D> change,
    required Object? Function(D row) field,
    required Object? expectedAfterChange,
  }) async {
    final name = repo.tableName;

    // Create.
    final created = await repo.insert(create);
    final m1 = created.toJson();
    final id = m1['id'] as String;
    expect(m1['userId'], r.context.userId, reason: '$name user_id');
    expect(m1['version'], 1, reason: '$name version starts at 1');
    expect(m1['deletedAt'], isNull, reason: name);

    // Read.
    expect((await repo.getById(id))!.toJson(), m1, reason: '$name read');
    expect(await repo.getAll(), hasLength(greaterThanOrEqualTo(1)));

    // Update (AC4: version++ and fresh updated_at).
    final updated = await repo.update(id, change);
    final m2 = updated.toJson();
    expect(field(updated), expectedAfterChange, reason: '$name update');
    expect(m2['version'], 2, reason: '$name version bump');
    expect(
      m2['updatedAt'] as int,
      greaterThan(m1['updatedAt'] as int),
      reason: '$name updated_at',
    );
    expect(m2['id'], id);

    // Soft delete.
    await repo.softDelete(id);
    expect(await repo.getById(id), isNull, reason: '$name hidden after delete');
    final deleted = (await repo.getById(id, includeDeleted: true))!.toJson();
    expect(deleted['deletedAt'], isNotNull, reason: '$name deleted_at');
    expect(deleted['version'], 3, reason: name);
    await expectLater(
      repo.update(id, change),
      throwsStateError,
      reason: '$name: deleted rows are read-only',
    );

    // AC3: exactly one outbox op per write, with the right base version.
    final ops = await opsFor(db, id);
    expect(ops.map((o) => (o.op, o.baseVersion, o.targetTable)).toList(), [
      ('insert', 0, name),
      ('update', 1, name),
      ('delete', 2, name),
    ], reason: '$name outbox');
    expect(
      jsonDecode(ops[1].payload)['version'],
      2,
      reason: '$name payload is the row after the write',
    );
  }

  test(
    'every syncable table supports CRUD + soft delete with outbox',
    () async {
      // Parent rows for foreign keys.
      final person = await r.persons.insert(
        PersonsCompanion.insert(name: 'Ali'),
      );
      final doc = await r.documents.insert(
        DocumentsCompanion.insert(title: 'K-Electric Bill — Nov 2026'),
      );
      final task = await r.tasks.insert(
        TasksCompanion.insert(title: 'Pay rent'),
      );

      await exercise(
        r.userSettings,
        create: const UserSettingsCompanion(),
        change: const UserSettingsCompanion(themeTemplate: Value('classic')),
        field: (s) => s.themeTemplate,
        expectedAfterChange: 'classic',
      );
      await exercise(
        r.persons,
        create: PersonsCompanion.insert(name: 'Ayesha'),
        change: const PersonsCompanion(relation: Value('spouse')),
        field: (p) => p.relation,
        expectedAfterChange: 'spouse',
      );
      await exercise(
        r.folders,
        create: FoldersCompanion.insert(name: 'Trips'),
        change: const FoldersCompanion(name: Value('Travel')),
        field: (f) => f.name,
        expectedAfterChange: 'Travel',
      );
      await exercise(
        r.documents,
        create: DocumentsCompanion.insert(
          title: 'Passport',
          personId: Value(person.id),
        ),
        change: const DocumentsCompanion(expiryDate: Value('2027-03-01')),
        field: (d) => d.expiryDate,
        expectedAfterChange: '2027-03-01',
      );
      await exercise(
        r.documentFiles,
        create: DocumentFilesCompanion.insert(
          documentId: doc.id,
          byteSize: 1024,
          sha256: 'abc',
        ),
        change: const DocumentFilesCompanion(pageNo: Value(2)),
        field: (f) => f.pageNo,
        expectedAfterChange: 2,
      );
      await exercise(
        r.extractedFields,
        create: ExtractedFieldsCompanion.insert(
          documentId: doc.id,
          field: 'amount',
          value: '4850',
        ),
        change: const ExtractedFieldsCompanion(
          value: Value('4950'),
          corrected: Value(true),
        ),
        field: (f) => f.value,
        expectedAfterChange: '4950',
      );
      await exercise(
        r.atcRules,
        create: AtcRulesCompanion.insert(kind: 'fixed', name: 'Rent'),
        change: const AtcRulesCompanion(status: Value('active')),
        field: (a) => a.status,
        expectedAfterChange: 'active',
      );
      await exercise(
        r.tasks,
        create: TasksCompanion.insert(title: 'Call electrician'),
        change: const TasksCompanion(priority: Value(2)),
        field: (t) => t.priority,
        expectedAfterChange: 2,
      );
      await exercise(
        r.subtasks,
        create: SubtasksCompanion.insert(
          taskId: task.id,
          title: 'Find receipt',
        ),
        change: const SubtasksCompanion(done: Value(true)),
        field: (s) => s.done,
        expectedAfterChange: true,
      );
      await exercise(
        r.taskReminders,
        create: TaskRemindersCompanion.insert(
          taskId: task.id,
          fireAt: 1793232000000,
        ),
        change: const TaskRemindersCompanion(fireAt: Value(1793235600000)),
        field: (t) => t.fireAt,
        expectedAfterChange: 1793235600000,
      );
      await exercise(
        r.categories,
        create: CategoriesCompanion.insert(name: 'Groceries'),
        change: const CategoriesCompanion(icon: Value('🛒')),
        field: (c) => c.icon,
        expectedAfterChange: '🛒',
      );
      await exercise(
        r.payments,
        create: PaymentsCompanion.insert(
          title: 'Rent',
          dueDate: '2026-11-01',
          periodMonth: '2026-11-01',
        ),
        change: const PaymentsCompanion(amountMinor: Value(4500000)),
        field: (p) => p.amountMinor,
        expectedAfterChange: 4500000,
      );
      await exercise(
        r.expenses,
        create: ExpensesCompanion.insert(
          amountMinor: 125000,
          spentOn: '2026-11-08',
        ),
        change: const ExpensesCompanion(note: Value('Groceries')),
        field: (e) => e.note,
        expectedAfterChange: 'Groceries',
      );
      await exercise(
        r.scoreSnapshots,
        create: ScoreSnapshotsCompanion.insert(
          day: '2026-11-08',
          score: 78,
          components: '{}',
          drags: '[]',
        ),
        change: const ScoreSnapshotsCompanion(score: Value(81)),
        field: (s) => s.score,
        expectedAfterChange: 81,
      );
    },
  );

  test('callers cannot override managed sync columns', () async {
    final p = await r.persons.insert(
      const PersonsCompanion(
        id: Value('hand-made-id'),
        name: Value('Bilal'),
        version: Value(99),
        userId: Value('someone-else'),
      ),
    );
    expect(p.id, isNot('hand-made-id'));
    expect(p.version, 1);
    expect(p.userId, r.context.userId);

    final u = await r.persons.update(
      p.id,
      const PersonsCompanion(version: Value(50)),
    );
    expect(u.version, 2);
  });

  test('getAll hides soft-deleted rows unless asked', () async {
    final a = await r.folders.insert(FoldersCompanion.insert(name: 'A'));
    await r.folders.insert(FoldersCompanion.insert(name: 'B'));
    await r.folders.softDelete(a.id);
    expect((await r.folders.getAll()).map((f) => f.name), ['B']);
    expect(await r.folders.getAll(includeDeleted: true), hasLength(2));
  });

  test('a failed write leaves no row and no outbox entry', () async {
    final before = await db.select(db.pendingOps).get();
    await expectLater(
      r.subtasks.insert(
        SubtasksCompanion.insert(taskId: 'missing', title: 'orphan'),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.subtasks).get(), isEmpty);
    expect(await db.select(db.pendingOps).get(), hasLength(before.length));
  });

  test('the local user id is created once and survives reopening', () async {
    final again = await Repositories.open(db);
    expect(again.context.userId, r.context.userId);
  });
}
