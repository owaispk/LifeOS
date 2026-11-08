// PBI-005: VaultService against a real (in-memory) SQLite database.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/vault/data/vault_service.dart';
import 'package:lifeos_app/features/vault/domain/vault_rules.dart';

import '../../data/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late VaultService service;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    service = VaultService(repos);
  });
  tearDown(() => db.close());

  Future<Folder> systemFolder(String kind) async =>
      (await repos.folders.getAll()).firstWhere((f) => f.kind == kind);

  Future<Document> addDoc(String title, {String? folderId, String? personId}) =>
      repos.documents.insert(
        DocumentsCompanion.insert(
          title: title,
          folderId: Value(folderId),
          personId: Value(personId),
        ),
      );

  test('AC1: one folder, one person, many tags per document', () async {
    final ali = await service.addPerson(name: 'Ali', relation: 'child');
    final identity = await systemFolder('identity');
    final d = await addDoc('Passport');

    await service.move(d.id, folderId: identity.id, personId: ali.id);
    final tagged = await service.setTags(d.id, ['travel', 'Travel', 'urgent']);
    expect(tagged.folderId, identity.id);
    expect(tagged.personId, ali.id);
    expect(parseTags(tagged.tags), ['travel', 'urgent']);

    // Moving replaces — never two folders or two people.
    final edu = await systemFolder('education');
    final moved = await service.move(d.id, folderId: edu.id, personId: null);
    expect((moved.folderId, moved.personId), (edu.id, null));
  });

  group('AC4: folders', () {
    test('system folders cannot be renamed or deleted', () async {
      final bills = await systemFolder('bills');
      await expectLater(
        service.deleteFolder(bills.id),
        throwsA(isA<ProtectedItemException>()),
      );
      await expectLater(
        service.updateFolder(bills.id, name: 'Mine', icon: '📁'),
        throwsA(isA<ProtectedItemException>()),
      );
      expect(await repos.folders.getById(bills.id), isNotNull);
    });

    test('deleting a custom folder moves its documents to Unfiled', () async {
      final trips = await service.addFolder(name: 'Trips', icon: '✈️');
      final a = await addDoc('Hotel booking', folderId: trips.id);
      final b = await addDoc('Flight ticket', folderId: trips.id);

      await service.deleteFolder(trips.id);
      expect(await repos.folders.getById(trips.id), isNull);
      for (final id in [a.id, b.id]) {
        final d = (await repos.documents.getById(id))!;
        expect(d.folderId, isNull, reason: 'moved to Unfiled');
        expect(d.deletedAt, isNull, reason: 'no data loss');
      }
    });

    test('custom folders can be renamed', () async {
      final f = await service.addFolder(name: 'Trips');
      final renamed = await service.updateFolder(
        f.id,
        name: ' Travel ',
        icon: '🧳',
      );
      expect((renamed.name, renamed.icon), ('Travel', '🧳'));
      expect(isSystemFolder(renamed), isFalse);
    });
  });

  group('people', () {
    test('deleting a person unassigns their documents and tasks', () async {
      final ammi = await service.addPerson(
        name: 'Ammi',
        relation: 'parent',
        avatar: '👵',
      );
      final d = await addDoc('Prescription', personId: ammi.id);
      final t = await repos.tasks.insert(
        TasksCompanion.insert(title: 'Buy medicine', personId: Value(ammi.id)),
      );

      await service.deletePerson(ammi.id);
      expect(await repos.persons.getById(ammi.id), isNull);
      expect((await repos.documents.getById(d.id))!.personId, isNull);
      expect((await repos.tasks.getById(t.id))!.personId, isNull);
    });

    test('"Me" can be renamed but not deleted, and stays self', () async {
      final me = (await repos.persons.getAll()).single;
      await expectLater(
        service.deletePerson(me.id),
        throwsA(isA<ProtectedItemException>()),
      );
      final renamed = await service.updatePerson(
        me.id,
        name: 'Owais',
        relation: 'child', // ignored for self
        avatar: '🧑',
      );
      expect((renamed.name, renamed.relation), ('Owais', 'self'));
    });

    test('names are required', () async {
      expect(
        () => service.addPerson(name: '  ', relation: 'child'),
        throwsArgumentError,
      );
      expect(() => service.addFolder(name: ''), throwsArgumentError);
    });
  });

  test('favourite, rename and delete a document', () async {
    final d = await addDoc('Scan · 8 Nov 2026');
    expect((await service.setFavorite(d.id, true)).favorite, isTrue);
    expect(
      (await service.renameDocument(d.id, 'Car papers')).title,
      'Car papers',
    );
    await service.deleteDocument(d.id);
    expect(await repos.documents.getById(d.id), isNull);
  });
}
