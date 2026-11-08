import 'package:drift/drift.dart';

import '../../../core/text.dart';
import '../../../data/db/app_database.dart';
import '../../money/domain/money_rules.dart' show isoDate;

/// "Added" date filter (PBI-006 grooming).
enum AddedWithin { any, last30Days, thisYear }

/// Search filters; combine with the text query (AND). Value-equal, so it
/// can key a provider.
typedef SearchFilters = ({
  String? personId,
  String? docType,
  AddedWithin added,
  bool expiringSoon,
});

const noFilters = (
  personId: null,
  docType: null,
  added: AddedWithin.any,
  expiringSoon: false,
);

bool hasFilters(SearchFilters f) =>
    f.personId != null ||
    f.docType != null ||
    f.added != AddedWithin.any ||
    f.expiringSoon;

class SearchHit {
  const SearchHit(this.document, this.snippet);
  final Document document;

  /// Matched text with the hit wrapped in « », or null.
  final String? snippet;
}

/// Builds an FTS5 MATCH expression: every word must match as a prefix.
/// Long numbers also match their thousands-separated form, so "4500" finds
/// "4,500" (tokenised as "4" "500"). Returns null when nothing searchable
/// is left.
String? ftsQuery(String input) {
  final words = normalizeDigits(input)
      .toLowerCase()
      .replaceAll(RegExp(r'["*^():]'), ' ')
      .split(RegExp(r'\s+'))
      .where(
        (w) => w
            .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
            .isNotEmpty,
      )
      .toList();
  if (words.isEmpty) return null;
  return words
      .map((w) {
        final phrase =
            '"${w.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim()}"*';
        if (RegExp(r'^\d{4,}$').hasMatch(w)) {
          final grouped = _groupThousands(w);
          return '($phrase OR "$grouped")';
        }
        return phrase;
      })
      .join(' AND ');
}

String _groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Lower bound for UUIDv7 ids created at or after [t] (ids sort by time).
String _idFloor(DateTime t) {
  final hex = t.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}';
}

/// Full-text Vault search (PBI-006) over the FTS5 index.
class SearchService {
  SearchService(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Future<List<SearchHit>> search(
    String query,
    SearchFilters filters, {
    int limit = 100,
  }) async {
    final match = ftsQuery(query);
    final where = <String>['d.deleted_at IS NULL'];
    final args = <Variable<Object>>[];

    if (filters.personId != null) {
      where.add('d.person_id = ?');
      args.add(Variable(filters.personId!));
    }
    if (filters.docType != null) {
      where.add('d.doc_type = ?');
      args.add(Variable(filters.docType!));
    }
    final now = _now();
    final since = switch (filters.added) {
      AddedWithin.any => null,
      AddedWithin.last30Days => DateTime(now.year, now.month, now.day - 30),
      AddedWithin.thisYear => DateTime(now.year),
    };
    if (since != null) {
      where.add('d.id >= ?');
      args.add(Variable(_idFloor(since)));
    }
    if (filters.expiringSoon) {
      final horizon = DateTime(now.year, now.month, now.day + 90);
      where.add('d.expiry_date IS NOT NULL AND d.expiry_date <= ?');
      args.add(Variable(isoDate(horizon)));
    }

    if (match == null) {
      if (!hasFilters(filters)) return const [];
      final rows = await _db
          .customSelect(
            'SELECT d.* FROM documents d WHERE ${where.join(' AND ')} '
            'ORDER BY d.favorite DESC, d.id DESC LIMIT ?',
            variables: [...args, Variable(limit)],
            readsFrom: {_db.documents},
          )
          .get();
      return [for (final r in rows) SearchHit(_db.documents.map(r.data), null)];
    }

    final rows = await _db
        .customSelect(
          'SELECT d.*, '
          "snippet(documents_fts, 2, '«', '»', '…', 10) AS snip "
          'FROM documents_fts '
          'JOIN documents d ON d.rowid = documents_fts.rowid '
          'WHERE documents_fts MATCH ? AND ${where.join(' AND ')} '
          'ORDER BY bm25(documents_fts) LIMIT ?',
          variables: [Variable(match), ...args, Variable(limit)],
          readsFrom: {_db.documents},
        )
        .get();
    return [
      for (final r in rows)
        SearchHit(_db.documents.map(r.data), r.readNullable<String>('snip')),
    ];
  }
}
