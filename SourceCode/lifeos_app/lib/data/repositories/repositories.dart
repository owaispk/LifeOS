import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import 'sync_repository.dart';

/// All repositories over one database, sharing one [DbContext].
class Repositories {
  Repositories._(this.db, this.context)
      : userSettings = SyncRepository(db, db.userSettings, context),
        persons = SyncRepository(db, db.persons, context),
        folders = SyncRepository(db, db.folders, context),
        documents = SyncRepository(db, db.documents, context),
        documentFiles = SyncRepository(db, db.documentFiles, context),
        extractedFields = SyncRepository(db, db.extractedFields, context),
        atcRules = SyncRepository(db, db.atcRules, context),
        tasks = SyncRepository(db, db.tasks, context),
        subtasks = SyncRepository(db, db.subtasks, context),
        taskReminders = SyncRepository(db, db.taskReminders, context),
        categories = SyncRepository(db, db.categories, context),
        payments = SyncRepository(db, db.payments, context),
        expenses = SyncRepository(db, db.expenses, context),
        scoreSnapshots = SyncRepository(db, db.scoreSnapshots, context);

  /// Opens repositories, creating the local (pre-signup) user id on first
  /// run. No account is needed to use the app (features spec §13).
  static Future<Repositories> open(
    AppDatabase db, {
    IdGenerator? ids,
    Clock clock = systemClock,
  }) async {
    final generator = ids ?? IdGenerator(nowMs: clock);
    final userId = await _ensureLocalUserId(db, generator);
    return Repositories._(
      db,
      DbContext(ids: generator, clock: clock, userId: userId),
    );
  }

  static const localUserIdKey = 'local_user_id';

  static Future<String> _ensureLocalUserId(
    AppDatabase db,
    IdGenerator ids,
  ) async {
    final existing = await (db.select(db.appMeta)
          ..where((m) => m.key.equals(localUserIdKey)))
        .getSingleOrNull();
    if (existing != null) return existing.value;
    final id = ids.next();
    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: localUserIdKey, value: id),
          mode: InsertMode.insertOrIgnore,
        );
    // Re-read in case a concurrent opener won the race.
    final row = await (db.select(db.appMeta)
          ..where((m) => m.key.equals(localUserIdKey)))
        .getSingle();
    return row.value;
  }

  final AppDatabase db;
  final DbContext context;

  final SyncRepository<$UserSettingsTable, UserSettingsRow> userSettings;
  final SyncRepository<$PersonsTable, Person> persons;
  final SyncRepository<$FoldersTable, Folder> folders;
  final SyncRepository<$DocumentsTable, Document> documents;
  final SyncRepository<$DocumentFilesTable, DocumentFile> documentFiles;
  final SyncRepository<$ExtractedFieldsTable, ExtractedField> extractedFields;
  final SyncRepository<$AtcRulesTable, AtcRule> atcRules;
  final SyncRepository<$TasksTable, Task> tasks;
  final SyncRepository<$SubtasksTable, Subtask> subtasks;
  final SyncRepository<$TaskRemindersTable, TaskReminder> taskReminders;
  final SyncRepository<$CategoriesTable, Category> categories;
  final SyncRepository<$PaymentsTable, Payment> payments;
  final SyncRepository<$ExpensesTable, Expense> expenses;
  final SyncRepository<$ScoreSnapshotsTable, ScoreSnapshot> scoreSnapshots;
}
