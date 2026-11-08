import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../db/app_database.dart';
import '../db/tables.dart';

/// Shared write context: who is writing, how ids and timestamps are made.
class DbContext {
  const DbContext({
    required this.ids,
    required this.clock,
    required this.userId,
  });

  final IdGenerator ids;
  final Clock clock;
  final String userId;
}

/// Sync columns callers may never set directly.
const _managedColumns = {
  'id',
  'user_id',
  'updated_at',
  'deleted_at',
  'version',
};

/// Offline-first CRUD for one syncable table (data model §1, §4.1).
///
/// Every write, in one transaction:
/// - sets `id` (UUIDv7, insert only), `user_id`, `updated_at`;
/// - bumps `version` (starts at 1);
/// - appends exactly one `pending_ops` outbox row with the row's new state
///   and the `base_version` the edit was made against (0 for inserts).
///
/// Deletes are soft (`deleted_at`). Reads hide soft-deleted rows unless
/// `includeDeleted` is true.
class SyncRepository<T extends SyncColumns, D extends DataClass> {
  SyncRepository(this._db, this._table, this._ctx);

  final AppDatabase _db;
  final TableInfo<T, D> _table;
  final DbContext _ctx;

  String get tableName => _table.actualTableName;

  // ── Reads ───────────────────────────────────────────────────────────────

  Future<D?> getById(String id, {bool includeDeleted = false}) {
    return (_db.select(_table)
          ..where((t) => _live(t, includeDeleted) & t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<D>> getAll({bool includeDeleted = false}) {
    return (_db.select(_table)..where((t) => _live(t, includeDeleted))).get();
  }

  Stream<List<D>> watchAll({bool includeDeleted = false}) {
    return (_db.select(_table)..where((t) => _live(t, includeDeleted))).watch();
  }

  /// Live rows matching [filter].
  Future<List<D>> getWhere(Expression<bool> Function(T t) filter) {
    return (_db.select(
      _table,
    )..where((t) => _live(t, false) & filter(t))).get();
  }

  /// Live rows matching [filter], re-emitted on every change.
  Stream<List<D>> watchWhere(Expression<bool> Function(T t) filter) {
    return (_db.select(
      _table,
    )..where((t) => _live(t, false) & filter(t))).watch();
  }

  // ── Writes ──────────────────────────────────────────────────────────────

  /// Inserts a new row and returns it as stored.
  Future<D> insert(Insertable<D> row) {
    return _db.transaction(() async {
      final id = _ctx.ids.next();
      final now = _ctx.clock();
      await _db
          .into(_table)
          .insert(
            RawValuesInsertable<D>({
              ..._userColumns(row),
              'id': Variable<String>(id),
              'user_id': Variable<String>(_ctx.userId),
              'updated_at': Variable<int>(now),
              'version': const Variable<int>(1),
            }),
          );
      final stored = (await getById(id))!;
      await _queue(id, 'insert', stored, baseVersion: 0, now: now);
      return stored;
    });
  }

  /// Applies [changes] to a live row. Throws [StateError] if the row does
  /// not exist or is soft-deleted.
  Future<D> update(String id, Insertable<D> changes) {
    return _db.transaction(() async {
      final base = await _requireVersion(id);
      final now = _ctx.clock();
      await _writeById(id, {
        ..._userColumns(changes),
        'version': Variable<int>(base + 1),
        'updated_at': Variable<int>(now),
      });
      final stored = (await getById(id))!;
      await _queue(id, 'update', stored, baseVersion: base, now: now);
      return stored;
    });
  }

  /// Soft-deletes a live row (sets `deleted_at`). Throws [StateError] if
  /// the row does not exist or is already deleted.
  Future<void> softDelete(String id) {
    return _db.transaction(() async {
      final base = await _requireVersion(id);
      final now = _ctx.clock();
      await _writeById(id, {
        'deleted_at': Variable<int>(now),
        'version': Variable<int>(base + 1),
        'updated_at': Variable<int>(now),
      });
      final stored = (await getById(id, includeDeleted: true))!;
      await _queue(id, 'delete', stored, baseVersion: base, now: now);
    });
  }

  /// Brings a soft-deleted row back (Trash → Restore). Throws [StateError]
  /// if the row doesn't exist or isn't deleted.
  Future<D> restore(String id) {
    return _db.transaction(() async {
      final row = await getById(id, includeDeleted: true);
      if (row == null || (row.toJson()['deletedAt'] == null)) {
        throw StateError('$tableName row $id is not in the trash');
      }
      final base = row.toJson()['version'] as int;
      final now = _ctx.clock();
      await _writeById(id, {
        'deleted_at': const Variable<int>(null),
        'version': Variable<int>(base + 1),
        'updated_at': Variable<int>(now),
      });
      final stored = (await getById(id))!;
      await _queue(id, 'restore', stored, baseVersion: base, now: now);
      return stored;
    });
  }

  /// Removes a row for good (Trash → Delete forever / 30-day purge). The
  /// outbox records a `purge` so other devices drop it too.
  Future<void> purge(String id) {
    return _db.transaction(() async {
      final row = await getById(id, includeDeleted: true);
      if (row == null) return;
      final now = _ctx.clock();
      await (_db.delete(_table)..where((t) => t.id.equals(id))).go();
      await _queue(
        id,
        'purge',
        row,
        baseVersion: row.toJson()['version'] as int,
        now: now,
      );
    });
  }

  // ── Internals ───────────────────────────────────────────────────────────

  Expression<bool> _live(T t, bool includeDeleted) =>
      includeDeleted ? const Constant(true) : t.deletedAt.isNull();

  Map<String, Expression<Object>> _userColumns(Insertable<D> row) {
    return Map.of(row.toColumns(true))
      ..removeWhere((name, _) => _managedColumns.contains(name));
  }

  Future<int> _requireVersion(String id) async {
    final query = _db.selectOnly(_table)
      ..addColumns([_table.asDslTable.version])
      ..where(
        _table.asDslTable.id.equals(id) & _table.asDslTable.deletedAt.isNull(),
      );
    final row = await query.getSingleOrNull();
    if (row == null) {
      throw StateError('$tableName row $id not found or deleted');
    }
    return row.read(_table.asDslTable.version)!;
  }

  Future<void> _writeById(String id, Map<String, Expression<Object>> values) {
    return (_db.update(
      _table,
    )..where((t) => t.id.equals(id))).write(RawValuesInsertable<D>(values));
  }

  Future<void> _queue(
    String rowId,
    String op,
    D row, {
    required int baseVersion,
    required int now,
  }) {
    return _db
        .into(_db.pendingOps)
        .insert(
          PendingOpsCompanion.insert(
            id: _ctx.ids.next(),
            targetTable: tableName,
            rowId: rowId,
            op: op,
            payload: jsonEncode(row.toJson()),
            baseVersion: baseVersion,
            queuedAt: now,
          ),
        );
  }
}
