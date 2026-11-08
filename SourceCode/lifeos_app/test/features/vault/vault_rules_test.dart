// PBI-005: pure Vault rules.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/ids.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/features/vault/domain/vault_rules.dart';

var _t = 1793145600000;
final _ids = IdGenerator(nowMs: () => _t += 1000);

Document doc(
  String title, {
  String? folderId,
  String? personId,
  bool favorite = false,
  String tags = '[]',
  String? issuer,
  String? expiry,
  int? deletedAt,
}) => Document(
  id: _ids.next(),
  userId: 'u',
  updatedAt: 0,
  version: 1,
  deletedAt: deletedAt,
  personId: personId,
  folderId: folderId,
  title: title,
  docType: 'other',
  issuer: issuer,
  expiryDate: expiry,
  currency: 'PKR',
  favorite: favorite,
  tags: tags,
  source: 'scan',
);

void main() {
  test('favourites first, then newest first', () {
    final a = doc('old');
    final b = doc('fav old', favorite: true);
    final c = doc('new');
    final d = doc('fav new', favorite: true);
    expect(sortDocuments([a, b, c, d]).map((x) => x.title), [
      'fav new',
      'fav old',
      'new',
      'old',
    ]);
  });

  test('folder counts include Unfiled and skip deleted', () {
    final counts = folderCounts([
      doc('a', folderId: 'f1'),
      doc('b', folderId: 'f1'),
      doc('c'),
      doc('d', folderId: 'f1', deletedAt: 1),
    ]);
    expect(counts, {'f1': 2, null: 1});
  });

  group('tags', () {
    test('normalise trims, drops empties and case-insensitive duplicates', () {
      expect(normaliseTags([' Tax ', 'tax', '', 'Home', 'TAX', 'home ']), [
        'Tax',
        'Home',
      ]);
    });
    test('encode → parse round-trip; bad JSON parses to empty', () {
      expect(parseTags(encodeTags(['Visa', 'Travel'])), ['Visa', 'Travel']);
      expect(parseTags('not json'), isEmpty);
      expect(parseTags('{"a":1}'), isEmpty);
    });
  });

  test('search matches title, issuer or tags; every word must match', () {
    final docs = [
      doc('Electricity bill Nov', issuer: 'K-Electric'),
      doc('Passport', tags: '["travel","Ali"]'),
      doc('Gas bill', issuer: 'SSGC'),
      doc('Deleted passport', deletedAt: 1),
    ];
    expect(searchDocuments(docs, 'k-electric').map((d) => d.title), [
      'Electricity bill Nov',
    ]);
    expect(searchDocuments(docs, 'PASSPORT').map((d) => d.title), ['Passport']);
    expect(searchDocuments(docs, 'travel ali').map((d) => d.title), [
      'Passport',
    ]);
    expect(searchDocuments(docs, 'bill'), hasLength(2));
    expect(searchDocuments(docs, 'bill ssgc').single.title, 'Gas bill');
    expect(searchDocuments(docs, '   '), isEmpty);
  });

  group('expiring soon', () {
    final now = DateTime(2026, 11, 8, 10);

    test('within 90 days or expired, soonest first', () {
      final list = expiringSoon([
        doc('in 28 days', expiry: '2026-12-06'),
        doc('in 120 days', expiry: '2027-03-08'),
        doc('expired', expiry: '2026-11-01'),
        doc('today', expiry: '2026-11-08'),
        doc('no expiry'),
        doc('deleted', expiry: '2026-11-10', deletedAt: 1),
      ], now);
      expect(list.map((e) => (e.document.title, e.daysLeft)), [
        ('expired', -7),
        ('today', 0),
        ('in 28 days', 28),
      ]);
      expect(list.map((e) => e.label), [
        'Expired 7d ago',
        'Expires today',
        '28d left',
      ]);
    });

    test('urgency: ≤7 critical, ≤30 soon, beyond later', () {
      expect(urgencyFor(-3), ExpiryUrgency.critical);
      expect(urgencyFor(7), ExpiryUrgency.critical);
      expect(urgencyFor(8), ExpiryUrgency.soon);
      expect(urgencyFor(30), ExpiryUrgency.soon);
      expect(urgencyFor(31), ExpiryUrgency.later);
    });
  });

  test('type labels and icons', () {
    expect(docTypeLabel('cnic'), 'CNIC');
    expect(docTypeLabel('passport'), 'Passport');
    expect(docTypeLabel('other'), 'Document');
    expect(docTypeIcon('bill'), '🧾');
    expect(docTypeIcon('unknown'), '📄');
  });
}
