// PBI-006: FTS5 search against a real SQLite database (AC1–AC5).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/vault/data/search_service.dart';

import '../../data/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late SearchService search;
  final now = DateTime(2026, 11, 8, 10);

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    search = SearchService(db, now: () => now);
  });
  tearDown(() => db.close());

  Future<Document> doc(
    String title, {
    String? issuer,
    String? ocr,
    String? personId,
    String type = 'other',
    String? expiry,
    String tags = '[]',
  }) => repos.documents.insert(
    DocumentsCompanion.insert(
      title: title,
      issuer: Value(issuer),
      ocrText: Value(ocr),
      personId: Value(personId),
      docType: Value(type),
      expiryDate: Value(expiry),
      tags: Value(tags),
    ),
  );

  Future<List<String>> titles(String q, [SearchFilters f = noFilters]) async =>
      [for (final h in await search.search(q, f)) h.document.title];

  test('query building: prefixes, AND, thousands, syntax stripped', () {
    expect(ftsQuery('pass'), '"pass"*');
    expect(
      ftsQuery('K-Electric 4500'),
      '"k electric"* AND ("4500"* OR "4 500")',
    );
    expect(ftsQuery('  "*()  '), isNull);
    expect(ftsQuery('۴۸۵۰'), '("4850"* OR "4 850")');
  });

  test('AC2: a word only in the OCR text finds the document', () async {
    await doc('Scan · 8 Nov 2026', ocr: 'Passport No AB1234567 Nationality');
    await doc('Something else', ocr: 'unrelated');
    expect(await titles('ab1234567'), ['Scan · 8 Nov 2026']);
    expect(await titles('national'), ['Scan · 8 Nov 2026'], reason: 'prefix');
  });

  test('AC3: "K-Electric 4500" matches issuer + OCR amount', () async {
    await doc(
      'Electricity Nov',
      issuer: 'K-Electric',
      ocr: 'Payable within due date Rs. 4,500',
    );
    await doc(
      'Electricity Oct',
      issuer: 'K-Electric',
      ocr: 'Payable Rs. 3,120',
    );
    await doc('Gas', issuer: 'SSGC', ocr: 'Amount payable 4500');
    expect(await titles('K-Electric 4500'), ['Electricity Nov']);
  });

  test('AC4: soft-deleted documents never appear', () async {
    final d = await doc('Passport (Ali)');
    await doc('Passport (Me)');
    await repos.documents.softDelete(d.id);
    expect(await titles('passport'), ['Passport (Me)']);
  });

  test('AC5: edits update results immediately (triggers)', () async {
    final d = await doc('Old title', ocr: 'nothing');
    expect(await titles('lease'), isEmpty);
    await repos.documents.update(
      d.id,
      const DocumentsCompanion(title: Value('Lease agreement')),
    );
    expect(await titles('lease'), ['Lease agreement']);
    expect(await titles('old'), isEmpty, reason: 'old text left the index');
    await repos.documents.update(
      d.id,
      const DocumentsCompanion(ocrText: Value('Landlord tenant hereby')),
    );
    expect(await titles('landlord'), ['Lease agreement']);
  });

  test('tags are searchable; snippets mark the hit', () async {
    await doc('Visa', tags: '["travel","schengen"]');
    final hits = await search.search('scheng', noFilters);
    expect(hits.single.document.title, 'Visa');
    await doc('Bill', ocr: 'The units consumed were 412 kWh this month');
    final snip = (await search.search('consumed', noFilters)).single.snippet;
    expect(snip, contains('«consumed»'));
  });

  test('filters combine with the query and work alone', () async {
    final me = (await repos.persons.getAll()).single;
    await doc(
      'Passport',
      personId: me.id,
      type: 'passport',
      expiry: '2026-12-01',
    );
    await doc('Passport (Ali)', type: 'passport', expiry: '2030-01-01');
    await doc('CNIC', personId: me.id, type: 'cnic');

    final mine = (
      personId: me.id,
      docType: null,
      added: AddedWithin.any,
      expiringSoon: false,
    );
    expect(await titles('passport', mine), ['Passport']);
    expect((await titles('', mine)).toSet(), {'Passport', 'CNIC'});

    final expiring = (
      personId: null,
      docType: null,
      added: AddedWithin.any,
      expiringSoon: true,
    );
    expect(await titles('', expiring), ['Passport']);

    final ids = (
      personId: null,
      docType: 'cnic',
      added: AddedWithin.last30Days,
      expiringSoon: false,
    );
    expect(await titles('', ids), ['CNIC']);
    expect(await titles('', noFilters), isEmpty, reason: 'nothing to search');
  });

  test('AC1: 500 documents answer in under 1 s', () async {
    await db.transaction(() async {
      for (var i = 0; i < 500; i++) {
        await doc(
          'Document $i',
          issuer: i.isEven ? 'K-Electric' : 'SSGC',
          ocr:
              'Account No ${400000 + i} Bill Month NOV-26 Units ${100 + i} '
              'Payable within due date Rs. ${1000 + i * 7} '
              'Lorem ipsum dolor sit amet consectetur adipiscing elit',
        );
      }
    });
    final sw = Stopwatch()..start();
    final hits = await search.search('k-electric payable', noFilters);
    final hits2 = await search.search('400321', noFilters);
    sw.stop();
    // ignore: avoid_print
    print('500-doc search: ${sw.elapsedMilliseconds} ms (2 queries)');
    expect(hits, hasLength(100), reason: 'limit');
    expect(hits2.single.document.title, 'Document 321');
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });
}
