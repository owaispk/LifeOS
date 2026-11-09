import 'package:drift/drift.dart';

import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../domain/vault_rules.dart';

/// Thrown when a protected item (system folder, the "self" profile) would
/// be renamed or deleted.
class ProtectedItemException implements Exception {
  const ProtectedItemException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Vault organisation use-cases for PBI-005. Writes go through
/// [Repositories]; deletions never lose documents.
class VaultService {
  VaultService(this._repos);

  final Repositories _repos;

  AppDatabase get _db => _repos.db;

  // ── People ──────────────────────────────────────────────────────────────

  Future<Person> addPerson({
    required String name,
    required String relation,
    String? avatar,
  }) async {
    final people = await _repos.persons.getAll();
    return _repos.persons.insert(
      PersonsCompanion.insert(
        name: _requireName(name),
        relation: Value(relation),
        avatar: Value(avatar),
        sortOrder: Value(people.length),
      ),
    );
  }

  Future<Person> updatePerson(
    String id, {
    required String name,
    required String relation,
    String? avatar,
  }) async {
    final p = await _requirePerson(id);
    return _repos.persons.update(
      id,
      PersonsCompanion(
        name: Value(_requireName(name)),
        // "Me" stays "self" so it can never be lost.
        relation: Value(p.relation == 'self' ? 'self' : relation),
        avatar: Value(avatar),
      ),
    );
  }

  /// Soft-deletes a person; their documents and tasks become unassigned.
  Future<void> deletePerson(String id) async {
    final p = await _requirePerson(id);
    if (p.relation == 'self') {
      throw ProtectedItemException(l10nNow.vtOwnProfileProtected);
    }
    await _db.transaction(() async {
      for (final d in await _repos.documents.getWhere(
        (d) => d.personId.equals(id),
      )) {
        await _repos.documents.update(
          d.id,
          const DocumentsCompanion(personId: Value(null)),
        );
      }
      for (final t in await _repos.tasks.getWhere(
        (t) => t.personId.equals(id),
      )) {
        await _repos.tasks.update(
          t.id,
          const TasksCompanion(personId: Value(null)),
        );
      }
      await _repos.persons.softDelete(id);
    });
  }

  // ── Folders ─────────────────────────────────────────────────────────────

  Future<Folder> addFolder({required String name, String icon = '📁'}) async {
    final folders = await _repos.folders.getAll();
    return _repos.folders.insert(
      FoldersCompanion.insert(
        name: _requireName(name),
        icon: Value(icon),
        sortOrder: Value(folders.length),
      ),
    );
  }

  Future<Folder> updateFolder(
    String id, {
    required String name,
    required String icon,
  }) async {
    final f = await _requireFolder(id);
    if (isSystemFolder(f)) {
      throw ProtectedItemException(l10nNow.vtSystemFolderNoRename);
    }
    return _repos.folders.update(
      id,
      FoldersCompanion(name: Value(_requireName(name)), icon: Value(icon)),
    );
  }

  /// Soft-deletes a custom folder; its documents move to Unfiled.
  Future<void> deleteFolder(String id) async {
    final f = await _requireFolder(id);
    if (isSystemFolder(f)) {
      throw ProtectedItemException(l10nNow.vtSystemFolderNoDelete);
    }
    await _db.transaction(() async {
      for (final d in await _repos.documents.getWhere(
        (d) => d.folderId.equals(id),
      )) {
        await _repos.documents.update(
          d.id,
          const DocumentsCompanion(folderId: Value(null)),
        );
      }
      await _repos.folders.softDelete(id);
    });
  }

  // ── Documents ───────────────────────────────────────────────────────────

  Future<Document> renameDocument(String id, String title) => _repos.documents
      .update(id, DocumentsCompanion(title: Value(_requireName(title))));

  Future<Document> setFavorite(String id, bool favorite) => _repos.documents
      .update(id, DocumentsCompanion(favorite: Value(favorite)));

  Future<Document> setTags(String id, Iterable<String> tags) => _repos.documents
      .update(id, DocumentsCompanion(tags: Value(encodeTags(tags))));

  /// Moves a document to a folder (null = Unfiled) and/or person
  /// (null = nobody). A document has at most one of each.
  Future<Document> move(
    String id, {
    required String? folderId,
    required String? personId,
  }) => _repos.documents.update(
    id,
    DocumentsCompanion(folderId: Value(folderId), personId: Value(personId)),
  );

  Future<void> deleteDocument(String id) => _repos.documents.softDelete(id);

  /// Archived documents leave folder lists but stay searchable (PBI-007).
  Future<Document> archive(String id, {DateTime? at}) =>
      _repos.documents.update(
        id,
        DocumentsCompanion(
          archivedAt: Value((at ?? DateTime.now()).millisecondsSinceEpoch),
        ),
      );

  Future<Document> unarchive(String id) => _repos.documents.update(
    id,
    const DocumentsCompanion(archivedAt: Value(null)),
  );

  /// Saves edits from the viewer's info panel (type and main fields).
  Future<Document> updateDetails(String id, DocumentsCompanion changes) =>
      _repos.documents.update(id, changes);

  // ── Helpers ─────────────────────────────────────────────────────────────

  static String _requireName(String name) {
    final t = name.trim();
    if (t.isEmpty) throw ArgumentError.value(name, 'name', 'empty');
    return t;
  }

  Future<Person> _requirePerson(String id) async {
    final p = await _repos.persons.getById(id);
    if (p == null) throw StateError('Person $id not found');
    return p;
  }

  Future<Folder> _requireFolder(String id) async {
    final f = await _repos.folders.getById(id);
    if (f == null) throw StateError('Folder $id not found');
    return f;
  }
}
