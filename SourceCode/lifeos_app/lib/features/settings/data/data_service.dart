import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../../data/seed.dart';
import '../../security/crypto/vault_crypto.dart';
import '../../security/crypto/vault_files.dart';
import '../../../core/log/app_log.dart';

/// Key in `app_meta` set once onboarding is finished or skipped (PBI-022).
const onboardingDoneKey = 'onboarding_done';

/// What an export contains, for the confirmation message.
class ExportResult {
  const ExportResult(this.zip, this.documentCount);
  final Uint8List zip;
  final int documentCount;
}

/// Export and "Delete all local data" (PBI-025).
class DataService {
  DataService(this._repos, this._files, this._keyStore, this._vaultRoot);

  final Repositories _repos;
  final VaultFiles _files;
  final KeyStore _keyStore;
  final Directory? _vaultRoot;

  AppDatabase get _db => _repos.db;

  /// The synced tables, exported as one CSV each (AC3).
  List<TableInfo<Table, Object?>> get _tables => [
    _db.userSettings,
    _db.persons,
    _db.folders,
    _db.documents,
    _db.documentFiles,
    _db.extractedFields,
    _db.atcRules,
    _db.tasks,
    _db.subtasks,
    _db.taskReminders,
    _db.categories,
    _db.payments,
    _db.expenses,
    _db.scoreSnapshots,
    _db.shareEvents,
    _db.bundleTemplates,
  ];

  /// [_tables] with every row deleted before the rows it references, so
  /// the enforced foreign keys never block "Delete everything" (an ATC rule
  /// points at a category, a payment at a task, a task at a document…).
  List<TableInfo<Table, Object?>> get _deleteOrder => [
    _db.shareEvents,
    _db.bundleTemplates,
    _db.expenses,
    _db.payments,
    _db.taskReminders,
    _db.subtasks,
    _db.tasks,
    _db.atcRules,
    _db.extractedFields,
    _db.documentFiles,
    _db.documents,
    _db.categories,
    _db.folders,
    _db.persons,
    _db.scoreSnapshots,
    _db.userSettings,
  ];

  /// A ZIP of every live document (decrypted) under
  /// `documents/<Folder>/<title>.<ext>`, plus `data/<table>.csv` for every
  /// table and `data/export.json` with everything.
  Future<ExportResult> export() async {
    final archive = Archive();
    final folders = {
      for (final f in await _repos.folders.getAll()) f.id: f.name,
    };
    final docs = await _repos.documents.getAll();
    final used = <String>{};
    var count = 0;
    for (final d in docs) {
      final files = (await _repos.documentFiles.getWhere(
        (f) => f.documentId.equals(d.id),
      ))..sort((a, b) => a.pageNo.compareTo(b.pageNo));
      final readable = files.where(
        (f) => f.localPath != null && File(f.localPath!).existsSync(),
      );
      if (readable.isEmpty) continue;
      count++;
      final folder = _safe(folders[d.folderId] ?? 'Unfiled');
      for (final f in readable) {
        final ext = f.mime == 'application/pdf' ? 'pdf' : 'jpg';
        final suffix = files.length > 1 ? ' p${f.pageNo}' : '';
        var name = 'documents/$folder/${_safe(d.title)}$suffix.$ext';
        for (var i = 2; used.contains(name); i++) {
          name = 'documents/$folder/${_safe(d.title)}$suffix ($i).$ext';
        }
        used.add(name);
        final bytes = await _files.read(f);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
    }

    final json = <String, Object?>{};
    for (final t in _tables) {
      final rows = await _db.select(t).get();
      final maps = [
        for (final r in rows)
          if (r is DataClass) r.toJson(),
      ].where((m) => m['deletedAt'] == null).toList();
      json[t.actualTableName] = maps;
      final csv = utf8.encode(_csv(maps));
      archive.addFile(
        ArchiveFile('data/${t.actualTableName}.csv', csv.length, csv),
      );
    }
    final all = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
    archive.addFile(ArchiveFile('data/export.json', all.length, all));
    AppLog.i('data', 'export: $count documents');
    return ExportResult(
      Uint8List.fromList(ZipEncoder().encode(archive)),
      count,
    );
  }

  /// Removes the database rows, the Vault files and the keys (AC5). The
  /// local user id survives so the app keeps working; defaults are seeded
  /// again and onboarding shows next.
  Future<void> deleteAll(VaultCrypto crypto) async {
    await _db.transaction(() async {
      for (final t in _deleteOrder) {
        await _db.delete(t).go();
      }
      await _db.delete(_db.pendingOps).go();
      await _db.delete(_db.conflictLog).go();
      await _db.delete(_db.blobCache).go();
      await (_db.delete(
        _db.appMeta,
      )..where((m) => m.key.isNotValue(Repositories.localUserIdKey))).go();
    });
    final root = _vaultRoot;
    if (root != null && await root.exists()) await root.delete(recursive: true);
    await _keyStore.clear();
    crypto.forget();
    await seedDefaults(_repos);
    AppLog.w('data', 'all local data deleted');
  }
}

String _safe(String s) {
  final cleaned = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'Untitled' : cleaned;
}

String _csv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final cols = rows.first.keys.toList();
  String cell(Object? v) {
    final s = v == null ? '' : '$v';
    return s.contains(RegExp(r'[",\n\r]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return [
    cols.join(','),
    for (final r in rows) cols.map((c) => cell(r[c])).join(','),
  ].join('\n');
}
