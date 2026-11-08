// PBI-007: Trash — restore intact (AC3), delete forever, 30-day purge on
// start with a fixed clock (AC4).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/vault/data/trash_service.dart';
import 'package:path/path.dart' as p;

import '../../data/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late Directory tmp;
  var now = DateTime(2026, 11, 8, 10);
  late TrashService trash;

  setUp(() async {
    db = memoryDb();
    tmp = await Directory.systemTemp.createTemp('lifeos_trash_');
    repos = await openLocalData(db);
    now = DateTime(2026, 11, 8, 10);
    trash = TrashService(repos, now: () => now);
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// A full document: file on disk, page row, extracted field, and links
  /// from a task, a payment and an expense.
  Future<(Document, File)> fullDoc(String title) async {
    final doc = await repos.documents.insert(
      DocumentsCompanion.insert(
        title: title,
        docType: const Value('bill'),
        issuer: const Value('K-Electric'),
        amountMinor: const Value(485000),
        tags: const Value('["home"]'),
      ),
    );
    final dir = await Directory(p.join(tmp.path, doc.id)).create();
    final file = await File(p.join(dir.path, 'page.pdf')).writeAsBytes([1, 2]);
    await repos.documentFiles.insert(
      DocumentFilesCompanion.insert(
        documentId: doc.id,
        byteSize: 2,
        sha256: 'x',
        localPath: Value(file.path),
      ),
    );
    await repos.extractedFields.insert(
      ExtractedFieldsCompanion.insert(
        documentId: doc.id,
        field: 'amount',
        value: '485000',
      ),
    );
    await repos.tasks.insert(
      TasksCompanion.insert(title: 'Pay', sourceDocumentId: Value(doc.id)),
    );
    final payment = await repos.payments.insert(
      PaymentsCompanion.insert(
        title: 'Electricity',
        dueDate: '2026-11-14',
        periodMonth: '2026-11-01',
        receiptDocumentId: Value(doc.id),
      ),
    );
    await repos.expenses.insert(
      ExpensesCompanion.insert(
        amountMinor: 485000,
        spentOn: '2026-11-08',
        paymentId: Value(payment.id),
        receiptDocumentId: Value(doc.id),
      ),
    );
    return (doc, file);
  }

  test(
    'AC3: delete → Trash; restore brings back every field and file',
    () async {
      final (doc, file) = await fullDoc('K-Electric Nov');
      await repos.documents.softDelete(doc.id);
      expect((await trash.trashed()).single.id, doc.id);
      expect(await repos.documents.getById(doc.id), isNull);

      final restored = await trash.restore(doc.id);
      expect(
        (restored.title, restored.issuer, restored.amountMinor, restored.tags),
        ('K-Electric Nov', 'K-Electric', 485000, '["home"]'),
      );
      expect(await trash.trashed(), isEmpty);
      expect(await file.exists(), isTrue);
      final ops = await opsFor(db, doc.id);
      expect(ops.map((o) => o.op), containsAllInOrder(['delete', 'restore']));
    },
  );

  test('restoring a live document is refused', () async {
    final (doc, _) = await fullDoc('x');
    await expectLater(trash.restore(doc.id), throwsStateError);
  });

  test('delete forever removes rows and files, keeps linked records', () async {
    final (doc, file) = await fullDoc('K-Electric Nov');
    await repos.documents.softDelete(doc.id);
    await trash.deleteForever(doc.id);

    expect(await repos.documents.getById(doc.id, includeDeleted: true), isNull);
    expect(await db.select(db.documentFiles).get(), isEmpty);
    expect(await db.select(db.extractedFields).get(), isEmpty);
    expect(await file.exists(), isFalse);
    expect(await file.parent.exists(), isFalse);
    // Task, payment and expense survive, just unlinked.
    expect((await repos.tasks.getAll()).single.sourceDocumentId, isNull);
    expect((await repos.payments.getAll()).single.receiptDocumentId, isNull);
    expect((await repos.expenses.getAll()).single.receiptDocumentId, isNull);
    expect((await opsFor(db, doc.id)).last.op, 'purge');
  });

  test('AC4: items older than 30 days are purged on start', () async {
    final (old, oldFile) = await fullDoc('Old');
    final (recent, _) = await fullDoc('Recent');
    // Deleted on 1 Oct and 1 Nov.
    final clockRepos = await Repositories.open(
      db,
      clock: () => DateTime(2026, 10, 1, 9).millisecondsSinceEpoch,
    );
    await clockRepos.documents.softDelete(old.id);
    final laterRepos = await Repositories.open(
      db,
      clock: () => DateTime(2026, 11, 1, 9).millisecondsSinceEpoch,
    );
    await laterRepos.documents.softDelete(recent.id);

    now = DateTime(2026, 11, 8, 10); // app starts
    expect(trash.daysLeft((await trash.trashed()).last), 0);
    // Deleted 1 Nov 09:00 → purged 1 Dec 09:00: 22 d 23 h → "23 days left".
    expect(trash.daysLeft((await trash.trashed()).first), 23);
    expect(await trash.purgeExpired(), 1);

    final left = await trash.trashed();
    expect(left.map((d) => d.title), ['Recent']);
    expect(await oldFile.exists(), isFalse);
  });
}
