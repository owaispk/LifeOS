// Pure Vault rules for PBI-005 — no database, no Flutter (except the
// display labels, which read the app's current language via `l10nNow`).
import 'dart:convert';

import '../../../core/ids.dart';
import '../../../core/l10n.dart';
import '../../../data/db/app_database.dart';

/// System folders can't be renamed or deleted.
bool isSystemFolder(Folder f) => f.kind != 'custom';

/// Creation time, from the UUIDv7 id (documents have no created_at column).
DateTime createdAt(Document d) =>
    DateTime.fromMillisecondsSinceEpoch(IdGenerator.timestampOf(d.id));

/// Favourites first, then newest first.
List<Document> sortDocuments(Iterable<Document> docs) {
  return docs.toList()..sort((a, b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    return b.id.compareTo(a.id); // UUIDv7 → newest first
  });
}

/// Live documents per folder id (null key = Unfiled).
Map<String?, int> folderCounts(Iterable<Document> docs) {
  final counts = <String?, int>{};
  for (final d in docs) {
    if (d.deletedAt != null || d.archivedAt != null) continue;
    counts[d.folderId] = (counts[d.folderId] ?? 0) + 1;
  }
  return counts;
}

// ──────────────────────────────── Tags ─────────────────────────────────────

List<String> parseTags(String json) {
  try {
    final v = jsonDecode(json);
    return v is List ? v.whereType<String>().toList() : const [];
  } on FormatException {
    return const [];
  }
}

/// Trims, drops empties and case-insensitive duplicates (first spelling
/// wins), keeps order.
List<String> normaliseTags(Iterable<String> tags) {
  final seen = <String>{};
  return [
    for (final t in tags.map((t) => t.trim()))
      if (t.isNotEmpty && seen.add(t.toLowerCase())) t,
  ];
}

String encodeTags(Iterable<String> tags) => jsonEncode(normaliseTags(tags));

// ──────────────────────────── Expiring soon ────────────────────────────────

enum ExpiryUrgency { critical, soon, later }

/// red ≤ 7 days (incl. expired), amber ≤ 30, grey beyond.
ExpiryUrgency urgencyFor(int daysLeft) => daysLeft <= 7
    ? ExpiryUrgency.critical
    : daysLeft <= 30
    ? ExpiryUrgency.soon
    : ExpiryUrgency.later;

class ExpiringDoc {
  const ExpiringDoc(this.document, this.daysLeft);
  final Document document;

  /// Negative when already expired.
  final int daysLeft;

  ExpiryUrgency get urgency => urgencyFor(daysLeft);

  String get label => daysLeft < 0
      ? l10nNow.vtExpiredAgo('${-daysLeft}')
      : daysLeft == 0
      ? l10nNow.vtExpiresToday
      : l10nNow.vtDaysLeftShort('$daysLeft');
}

/// Documents expiring within [windowDays] (or already expired), soonest
/// first.
List<ExpiringDoc> expiringSoon(
  Iterable<Document> docs,
  DateTime now, {
  int windowDays = 90,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final list = <ExpiringDoc>[];
  for (final d in docs) {
    if (d.deletedAt != null || d.archivedAt != null || d.expiryDate == null) {
      continue;
    }
    final p = d.expiryDate!.split('-').map(int.parse).toList();
    final expiry = DateTime(p[0], p[1], p[2]);
    // Calendar days (DST-safe): compare dates via UTC midnights.
    final days = DateTime.utc(
      expiry.year,
      expiry.month,
      expiry.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    if (days <= windowDays) list.add(ExpiringDoc(d, days));
  }
  return list..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
}

// ─────────────────────────────── Display ───────────────────────────────────

const _typeIcons = {
  'cnic': '🪪',
  'passport': '🛂',
  'visa': '🛂',
  'license': '🚗',
  'bill': '🧾',
  'fee_voucher': '🎓',
  'receipt': '🧾',
  'prescription': '💊',
  'report': '🏥',
  'degree': '🎓',
  'certificate': '📜',
  'warranty': '🛡️',
  'policy': '📄',
  'agreement': '📝',
};

String docTypeIcon(String type) => _typeIcons[type] ?? '📄';

String docTypeLabel(String type) {
  final l = l10nNow;
  return switch (type) {
    'cnic' => l.vtTypeCnic,
    'passport' => l.vtTypePassport,
    'visa' => l.vtTypeVisa,
    'license' => l.vtTypeLicense,
    'bill' => l.vtTypeBill,
    'fee_voucher' => l.vtTypeFeeVoucher,
    'receipt' => l.vtTypeReceipt,
    'prescription' => l.vtTypePrescription,
    'report' => l.vtTypeReport,
    'degree' => l.vtTypeDegree,
    'certificate' => l.vtTypeCertificate,
    'warranty' => l.vtTypeWarranty,
    'policy' => l.vtTypePolicy,
    'agreement' => l.vtTypeAgreement,
    'other' => l.vtTypeOther,
    _ => type[0].toUpperCase() + type.substring(1),
  };
}

/// A folder's display name: system folders (stored in English by the seed)
/// show in the app's language; custom folders show their own name.
String folderLabel(Folder f) {
  final l = l10nNow;
  return switch (f.kind) {
    'identity' => l.vtFolderIdentity,
    'education' => l.vtFolderEducation,
    'medical' => l.vtFolderMedical,
    'bills' => l.vtFolderBills,
    'property' => l.vtFolderProperty,
    'vehicles' => l.vtFolderVehicles,
    'insurance' => l.vtFolderInsurance,
    'work' => l.vtFolderWork,
    _ => f.name,
  };
}
