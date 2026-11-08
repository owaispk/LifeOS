// Schema upgrades: v1 (PBI-002) → v2 (Sprint 2: day capacity + phash).
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/db/app_database.dart';

import '../generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 → v2 produces exactly the v2 schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('v1 data survives the upgrade and gets v2 defaults', () async {
    final schema = await verifier.schemaAt(1);
    // Write v1 rows with raw SQL (the v1 app's shape).
    schema.rawDatabase.execute(
      "INSERT INTO user_settings (id, user_id, updated_at) "
      "VALUES ('s1', 'u1', 1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO documents (id, user_id, updated_at, title) "
      "VALUES ('d1', 'u1', 1, 'Passport')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO document_files "
      "(id, user_id, updated_at, document_id, byte_size, sha256) "
      "VALUES ('f1', 'u1', 1, 'd1', 2048, 'abc')",
    );

    final db = AppDatabase(schema.newConnection());
    final settings = await db.select(db.userSettings).getSingle();
    expect(settings.id, 's1');
    expect(settings.dayCapacityMin, 360);
    final file = await db.select(db.documentFiles).getSingle();
    expect((file.byteSize, file.sha256, file.phash), (2048, 'abc', null));
    await db.close();
  });
}
