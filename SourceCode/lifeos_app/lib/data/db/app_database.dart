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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // v2 (Sprint 2): Overload Shield capacity + duplicate-detection hash.
      if (from < 2) {
        await m.addColumn(userSettings, userSettings.dayCapacityMin);
        await m.addColumn(documentFiles, documentFiles.phash);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
