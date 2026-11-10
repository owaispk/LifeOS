// Schema upgrades: v1 (PBI-002) → v2 (Sprint 2: day capacity + phash)
// → v3 (Sprint 3: full-text search, archive/renewal).
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import 'db_test_utils.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  // The current database can only migrate to the current version; every
  // older starting point is checked against it.
  for (final (from, to) in [
    (1, 11), (2, 11), (3, 11), (4, 11), (5, 11), (6, 11), //
    (7, 11), (8, 11), (9, 11), (10, 11), //
  ]) {
    test('v$from → v$to produces exactly the v$to schema', () async {
      final connection = await verifier.startAt(from);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, to);
      await db.close();
    });
  }

  test('v1 data survives the upgrades and gets the new defaults', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase.execute(
      "INSERT INTO user_settings (id, user_id, updated_at) "
      "VALUES ('s1', 'u1', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO documents (id, user_id, updated_at, title, issuer, ocr_text) "
      "VALUES ('d1', 'u1', 1, 'Passport', NULL, 'Passport No AB1234567')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO document_files "
      "(id, user_id, updated_at, document_id, byte_size, sha256) "
      "VALUES ('f1', 'u1', 1, 'd1', 2048, 'abc')",
    );

    final db = AppDatabase(schema.newConnection());
    final settings = await db.select(db.userSettings).getSingle();
    expect((settings.id, settings.dayCapacityMin), ('s1', 360));
    // v7: greeting defaults to neutral auto (PBI-035).
    expect((settings.greetStyle, settings.greetCustom), ('auto', ''));
    // v8: an upgrade keeps what the user has always seen (PBI-035).
    expect(
      (settings.currencySymbol, settings.weekStart, settings.dateOrder),
      ('Rs', DateTime.monday, 'dm'),
    );
    final file = await db.select(db.documentFiles).getSingle();
    expect((file.byteSize, file.sha256, file.phash), (2048, 'abc', null));
    final doc = await db.select(db.documents).getSingle();
    expect(
      (doc.archivedAt, doc.renewedById, doc.expiryPromptedAt),
      (null, null, null),
    );
    expect((settings.salaryDay, settings.salaryMinor), (null, null));
    // v9: widget details default on (PBI-033).
    expect(settings.widgetDetails, true);

    // v3: documents written before the index existed are searchable.
    final hits = await db
        .customSelect(
          "SELECT rowid FROM documents_fts WHERE documents_fts MATCH 'AB1234567'",
        )
        .get();
    expect(hits, hasLength(1));
    await db.close();
  });

  test('a fresh install leaves region formats to the phone (PBI-035)', () async {
    final db = memoryDb();
    await db.into(db.userSettings).insert(UserSettingsCompanion.insert());
    final s = await db.select(db.userSettings).getSingle();
    expect((s.currencySymbol, s.weekStart, s.dateOrder), (null, null, null));
    await db.close();
  });
}
