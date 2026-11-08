// PBI-002 AC1: migration v1 creates every table.
import 'package:drift/drift.dart' show DriftSqlType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import 'db_test_utils.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test('the current schema creates all synced and local-only tables', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final tables = rows.map((r) => r.read<String>('name')).toSet();

    expect(tables, {
      // synced (data model §3.1–3.5)
      'user_settings', 'persons', 'folders', 'documents', 'document_files',
      'extracted_fields', 'atc_rules', 'tasks', 'subtasks', 'task_reminders',
      'categories', 'payments', 'expenses', 'score_snapshots',
      // local-only (data model §8.3) + app meta
      'pending_ops', 'conflict_log', 'blob_cache', 'app_meta',
      // full-text search (PBI-006) + FTS5's internal shadow tables
      'documents_fts', 'documents_fts_data', 'documents_fts_idx',
      'documents_fts_docsize', 'documents_fts_config',
    });
    expect(db.schemaVersion, 4);
  });

  test('every synced table carries sync metadata columns', () async {
    for (final table in db.allTables) {
      final names = table.$columns.map((c) => c.name).toSet();
      if ({
        'pending_ops',
        'conflict_log',
        'blob_cache',
        'app_meta',
        'documents_fts',
      }.contains(table.actualTableName)) {
        continue;
      }
      expect(
        names.containsAll({
          'id',
          'user_id',
          'updated_at',
          'deleted_at',
          'version',
        }),
        isTrue,
        reason: table.actualTableName,
      );
    }
  });

  test('money columns are integers (minor units), never REAL', () async {
    for (final table in db.allTables) {
      for (final c in table.$columns.where((c) => c.name.contains('amount'))) {
        expect(
          c.type,
          DriftSqlType.int,
          reason: '${table.actualTableName}.${c.name}',
        );
      }
    }
  });

  test('foreign keys are enforced', () async {
    await expectLater(
      db.customStatement(
        "INSERT INTO subtasks (id, user_id, updated_at, task_id, title) "
        "VALUES ('s1', 'u', 0, 'missing-task', 'x')",
      ),
      throwsA(anything),
    );
  });
}
