import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../core/ids.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The phone's working database (offline-first, data model §1.1).
@DriftDatabase(
  tables: [
    UserSettings,
    Persons,
    Folders,
    Documents,
    DocumentFiles,
    ExtractedFields,
    AtcRules,
    Tasks,
    Subtasks,
    TaskReminders,
    Categories,
    Payments,
    Expenses,
    ScoreSnapshots,
    PendingOps,
    ConflictLog,
    BlobCache,
    AppMeta,
  ],
  include: {'search.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device database file used by the app.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'lifeos',
      // Notification actions run in a background isolate (PBI-012); both
      // isolates must share one connection to the same file.
      native: const DriftNativeOptions(shareAcrossIsolates: true),
    ),
  );

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 (Sprint 2): Overload Shield capacity + duplicate-detection hash.
      if (from < 2) {
        await m.addColumn(userSettings, userSettings.dayCapacityMin);
        await m.addColumn(documentFiles, documentFiles.phash);
      }
      // v3 (Sprint 3): full-text search + archive/renewal links.
      if (from < 3) {
        await m.addColumn(documents, documents.archivedAt);
        await m.addColumn(documents, documents.renewedById);
        await m.create(documentsFts);
        await m.create(documentsFtsAi);
        await m.create(documentsFtsAd);
        await m.create(documentsFtsAu);
        await customStatement(
          "INSERT INTO documents_fts(documents_fts) VALUES ('rebuild')",
        );
      }
      // v4 (Sprint 4): rule categories, salary, expiry prompt.
      if (from < 4) {
        await m.addColumn(atcRules, atcRules.categoryId);
        await m.addColumn(userSettings, userSettings.salaryDay);
        await m.addColumn(userSettings, userSettings.salaryMinor);
        await m.addColumn(documents, documents.expiryPromptedAt);
      }
      // v5 (Sprint 5): meter references and date-based fee schedules.
      if (from < 5) {
        await m.addColumn(atcRules, atcRules.refNumber);
        await m.addColumn(atcRules, atcRules.scheduleDates);
      }
      // v6 (Sprint 6): language and Vault screenshot blocking.
      if (from < 6) {
        await m.addColumn(userSettings, userSettings.language);
        await m.addColumn(userSettings, userSettings.screenshotBlock);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
