// Local Drift schema — mirrors LifeOS-Founders-Pack/lifeos-data-model.md §3.
//
// Type mapping (data model §3 note + §8):
//   uuid        → TEXT (client-generated UUIDv7)
//   timestamptz → INTEGER epoch-ms, always UTC
//   date        → TEXT 'YYYY-MM-DD' (no timezone, sorts correctly)
//   time        → TEXT 'HH:mm'
//   jsonb/arrays→ TEXT (JSON)
//   money       → INTEGER minor units (`amount_minor`), never floats
//
// Every syncable table mixes in [SyncColumns]: id, user_id, updated_at,
// deleted_at (soft delete), version (optimistic counter).
import 'package:drift/drift.dart';

import '../../core/ids.dart';

///
/// Always write through `SyncRepository`: it sets id, user_id, updated_at
/// and version itself. The client defaults below only exist so generated
/// `XCompanion.insert(...)` constructors don't demand these values.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(fallbackIds.next)();
  TextColumn get userId => text().clientDefault(() => '')();
  IntColumn get updatedAt => integer().clientDefault(systemClock)();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ───────────────────────── 3.1 Identity & settings ─────────────────────────

/// One row per user. Deviation from spec: keyed by `id` like every other
/// syncable table (spec uses `user_id` as PK); `user_id` is unique instead.
@DataClassName('UserSettingsRow')
class UserSettings extends Table with SyncColumns {
  TextColumn get themeTemplate =>
      text().withDefault(const Constant('flagship'))(); // flagship|funky|classic
  TextColumn get darkMode => text().withDefault(const Constant('system'))();
  RealColumn get textScale => real().withDefault(const Constant(1.0))();
  BoolColumn get appLock => boolean().withDefault(const Constant(false))();
  BoolColumn get vaultLock => boolean().withDefault(const Constant(true))();
  IntColumn get autoLockMin => integer().withDefault(const Constant(5))();
  TextColumn get quietStart => text().withDefault(const Constant('22:00'))();
  TextColumn get quietEnd => text().withDefault(const Constant('07:00'))();
  TextColumn get digestTime => text().withDefault(const Constant('07:30'))();
  TextColumn get notifDomains => text().withDefault(const Constant('{}'))();
  TextColumn get backupMode =>
      text().withDefault(const Constant('wifi'))(); // off|wifi|always

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId},
      ];
}

/// Me / family profiles.
@DataClassName('Person')
class Persons extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get relation => text().withDefault(const Constant('self'))();
  TextColumn get avatar => text().nullable()();
  TextColumn get dob => text().nullable()();
  TextColumn get bloodGroup => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

// ───────────────────────────────── 3.2 Vault ───────────────────────────────

@DataClassName('Folder')
class Folders extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('📁'))();

  /// custom | identity | education | medical | bills | property | vehicles |
  /// insurance | work
  TextColumn get kind => text().withDefault(const Constant('custom'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('Document')
class Documents extends Table with SyncColumns {
  TextColumn get personId => text().nullable().references(Persons, #id)();
  TextColumn get folderId => text().nullable().references(Folders, #id)();
  TextColumn get title => text()();
  TextColumn get docType => text().withDefault(const Constant('other'))();
  TextColumn get issuer => text().nullable()();
  TextColumn get refNumber => text().nullable()();
  TextColumn get issueDate => text().nullable()();
  TextColumn get expiryDate => text().nullable()();
  TextColumn get expiryAlerts => text().nullable()(); // JSON e.g. [180,90,30]
  IntColumn get amountMinor => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get dueDate => text().nullable()();
  TextColumn get periodMonth => text().nullable()(); // first of month
  TextColumn get ocrText => text().nullable()();
  RealColumn get classificationConfidence => real().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON
  TextColumn get source =>
      text().withDefault(const Constant('scan'))(); // scan|import|share_in
}

@DataClassName('DocumentFile')
class DocumentFiles extends Table with SyncColumns {
  TextColumn get documentId => text().references(Documents, #id)();
  IntColumn get pageNo => integer().withDefault(const Constant(1))();
  TextColumn get r2Key => text().nullable()(); // null until backup enabled
  TextColumn get localPath => text().nullable()();
  IntColumn get byteSize => integer()();
  TextColumn get mime =>
      text().withDefault(const Constant('application/pdf'))();
  TextColumn get sha256 => text()();
  TextColumn get encIv => text().nullable()(); // set by PBI-024
  TextColumn get encKeyWrapped => text().nullable()(); // set by PBI-024
  TextColumn get thumbR2Key => text().nullable()();
}

@DataClassName('ExtractedField')
class ExtractedFields extends Table with SyncColumns {
  TextColumn get documentId => text().references(Documents, #id)();
  TextColumn get field => text()(); // amount|due_date|expiry|name|number…
  TextColumn get value => text()();
  RealColumn get confidence => real().nullable()();
  BoolColumn get corrected => boolean().withDefault(const Constant(false))();
}

// ───────────────────────────── 3.3 Tasks & ATC ─────────────────────────────

@DataClassName('AtcRule')
class AtcRules extends Table with SyncColumns {
  TextColumn get personId => text().nullable().references(Persons, #id)();

  /// fixed | bill_pattern | fee | appointment_followup
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get issuer => text().nullable()();
  IntColumn get amountMinor => integer().nullable()();
  IntColumn get amountAvgMinor => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  TextColumn get expectedWindow => text().nullable()(); // {"from":10,"to":14}

  /// monthly | quarterly | semester | yearly | once
  TextColumn get cycle => text().withDefault(const Constant('monthly'))();
  TextColumn get skipMonths => text().withDefault(const Constant('[]'))();
  IntColumn get installmentTotal => integer().nullable()();
  IntColumn get installmentDone => integer().nullable()();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(5))();

  /// proposed | active | paused | ended
  TextColumn get status => text().withDefault(const Constant('proposed'))();
  RealColumn get confidence => real().nullable()();
  TextColumn get lastGeneratedPeriod => text().nullable()();
  TextColumn get stats => text().withDefault(const Constant('{}'))();
}

@DataClassName('Task')
class Tasks extends Table with SyncColumns {
  TextColumn get personId => text().nullable().references(Persons, #id)();

  /// mind | money | health | people | work | soul | vault
  TextColumn get domain => text().withDefault(const Constant('mind'))();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get dueAt => integer().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(true))();
  /// 0 low, 1 med, 2 high.
  IntColumn get priority => integer()
      .withDefault(const Constant(1))
      // ignore: recursive_getters
      .check(priority.isBetweenValues(0, 2))();
  IntColumn get durationMin => integer().withDefault(const Constant(30))();

  /// open | done | skipped
  TextColumn get status => text().withDefault(const Constant('open'))();
  IntColumn get completedAt => integer().nullable()();
  TextColumn get repeatRule => text().nullable()(); // RRULE
  TextColumn get atcRuleId => text().nullable().references(AtcRules, #id)();
  TextColumn get sourceDocumentId =>
      text().nullable().references(Documents, #id)();
}

@DataClassName('Subtask')
class Subtasks extends Table with SyncColumns {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@DataClassName('TaskReminder')
class TaskReminders extends Table with SyncColumns {
  TextColumn get taskId => text().references(Tasks, #id)();
  IntColumn get fireAt => integer()();
  BoolColumn get fired =>
      boolean().withDefault(const Constant(false))(); // local only (§8.2)
}

// ───────────────────────────────── 3.4 Money ───────────────────────────────

@DataClassName('Category')
class Categories extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('expense'))();
  TextColumn get systemKey => text().nullable()(); // rent|fees|utilities…
}

@DataClassName('Payment')
class Payments extends Table with SyncColumns {
  TextColumn get taskId => text().nullable().references(Tasks, #id)();
  TextColumn get atcRuleId => text().nullable().references(AtcRules, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get title => text()();
  IntColumn get amountMinor => integer().nullable()(); // null until OCR fills
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get dueDate => text()();
  TextColumn get periodMonth => text()();

  /// upcoming | paid | overdue | skipped
  TextColumn get status => text().withDefault(const Constant('upcoming'))();
  IntColumn get paidAt => integer().nullable()();
  TextColumn get receiptDocumentId =>
      text().nullable().references(Documents, #id)();
}

@DataClassName('Expense')
class Expenses extends Table with SyncColumns {
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get paymentId => text().nullable().references(Payments, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('PKR'))();
  TextColumn get spentOn => text()();
  TextColumn get note => text().nullable()();
  TextColumn get receiptDocumentId =>
      text().nullable().references(Documents, #id)();
}

// ─────────────────────────── 3.5 Score & engagement ────────────────────────

/// Deviation from spec: keyed by `id` (spec PK is user_id+day); the
/// (user_id, day) pair is a unique key instead.
@DataClassName('ScoreSnapshot')
class ScoreSnapshots extends Table with SyncColumns {
  TextColumn get day => text()();
  // ignore: recursive_getters
  IntColumn get score => integer().check(score.isBetweenValues(0, 100))();
  TextColumn get components => text()(); // JSON
  TextColumn get drags => text()(); // JSON

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {userId, day},
      ];
}

// ─────────────────────── Local-only tables (data model §8.3) ───────────────

/// Sync outbox: one row per local write, pushed by PBI-026.
@DataClassName('PendingOp')
class PendingOps extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get op => text()(); // insert | update | delete
  TextColumn get payload => text()(); // JSON of the row after the write
  IntColumn get baseVersion => integer()(); // version the edit was based on
  IntColumn get queuedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ConflictLogEntry')
class ConflictLog extends Table {
  TextColumn get id => text()();
  TextColumn get targetTable => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get payload => text()();
  IntColumn get loggedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BlobCacheEntry')
class BlobCache extends Table {
  TextColumn get r2Key => text()();
  TextColumn get localPath => text()();
  IntColumn get lastUsed => integer()();

  @override
  Set<Column<Object>> get primaryKey => {r2Key};
}

/// Local key/value store (local user id, seed version…).
@DataClassName('AppMetaEntry')
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
