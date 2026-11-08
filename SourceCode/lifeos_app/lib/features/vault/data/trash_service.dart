import 'dart:io';

import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';

/// How long deleted documents stay restorable (PBI-007).
const trashDays = 30;

/// Vault Trash (PBI-007): list, restore, delete forever, 30-day purge.
class TrashService {
  TrashService(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  AppDatabase get _db => _repos.db;

  /// Deleted documents, most recently deleted first.
  Future<List<Document>> trashed() async {
    final all = await _repos.documents.getAll(includeDeleted: true);
    return all.where((d) => d.deletedAt != null).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
  }

  /// Whole days left before [d] is purged (never below 0).
  int daysLeft(Document d) {
    final deleted = DateTime.fromMillisecondsSinceEpoch(d.deletedAt!);
    final purgeOn = deleted.add(const Duration(days: trashDays));
    final left = purgeOn.difference(_now()).inHours / 24;
    return left <= 0 ? 0 : left.ceil();
  }

  Future<Document> restore(String id) => _repos.documents.restore(id);

  /// Deletes a document for good: its files on disk, page rows, extracted
  /// fields, and links from tasks / payments / expenses (set to null, never
  /// deleting them).
  Future<void> deleteForever(String id) async {
    final paths = <String>[];
    await _db.transaction(() async {
      for (final t in await _repos.tasks.getWhere(
        (t) => t.sourceDocumentId.equals(id),
      )) {
        await _repos.tasks.update(
          t.id,
          const TasksCompanion(sourceDocumentId: Value(null)),
        );
      }
      for (final p in await _repos.payments.getWhere(
        (p) => p.receiptDocumentId.equals(id),
      )) {
        await _repos.payments.update(
          p.id,
          const PaymentsCompanion(receiptDocumentId: Value(null)),
        );
      }
      for (final e in await _repos.expenses.getWhere(
        (e) => e.receiptDocumentId.equals(id),
      )) {
        await _repos.expenses.update(
          e.id,
          const ExpensesCompanion(receiptDocumentId: Value(null)),
        );
      }
      final files = await (_db.select(
        _db.documentFiles,
      )..where((f) => f.documentId.equals(id))).get();
      for (final f in files) {
        if (f.localPath != null) paths.add(f.localPath!);
        await _repos.documentFiles.purge(f.id);
      }
      final fields = await (_db.select(
        _db.extractedFields,
      )..where((f) => f.documentId.equals(id))).get();
      for (final f in fields) {
        await _repos.extractedFields.purge(f.id);
      }
      await _repos.documents.purge(id);
    });
    // Files go only after the rows are gone for sure.
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (paths.isNotEmpty) {
      final dir = File(paths.first).parent;
      if (await dir.exists() && (await dir.list().isEmpty)) await dir.delete();
    }
  }

  /// Purges everything deleted more than [trashDays] ago. Runs at app
  /// start. Returns how many documents were purged.
  Future<int> purgeExpired() async {
    final cutoff = _now()
        .subtract(const Duration(days: trashDays))
        .millisecondsSinceEpoch;
    var n = 0;
    for (final d in await trashed()) {
      if (d.deletedAt! <= cutoff) {
        await deleteForever(d.id);
        n++;
      }
    }
    return n;
  }
}
