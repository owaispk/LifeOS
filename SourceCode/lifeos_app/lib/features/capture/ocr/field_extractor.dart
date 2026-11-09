// Per-type field extraction from OCR text (PBI-004) — pure Dart, offline.
import '../../../core/l10n.dart';
import '../../../core/money.dart';
import '../../../core/text.dart';
import '../../../shared/format.dart';
import 'issuers.dart';

/// Field keys used in `extracted_fields.field` and the confirm screen.
abstract final class Fields {
  static const issuer = 'issuer';
  static const refNumber = 'ref_number';
  static const amount = 'amount'; // minor units as a string
  static const dueDate = 'due_date'; // YYYY-MM-DD
  static const periodMonth = 'period_month'; // YYYY-MM-01
  static const name = 'name';
  static const number = 'number';
  static const issueDate = 'issue_date';
  static const expiryDate = 'expiry_date';
  static const institution = 'institution';
  static const studentName = 'student_name';
  static const doctor = 'doctor';
  static const product = 'product';
  static const startDate = 'start_date';
  static const endDate = 'end_date';

  /// Display labels for the confirm screen, in the app's language.
  static Map<String, String> get labels {
    final l = l10nNow;
    return {
      issuer: l.cpFieldIssuer,
      refNumber: l.cpFieldRefNumber,
      amount: l.amount,
      dueDate: l.cpFieldDueDate,
      periodMonth: l.cpFieldBillingMonth,
      name: l.name,
      number: l.cpFieldNumber,
      issueDate: l.cpFieldIssueDate,
      expiryDate: l.cpFieldExpiryDate,
      institution: l.cpFieldInstitution,
      studentName: l.cpFieldStudent,
      doctor: l.cpFieldDoctor,
      product: l.cpFieldProduct,
      startDate: l.cpFieldStartDate,
      endDate: l.cpFieldEndDate,
    };
  }

  /// Which fields each type asks for, in display order.
  static const forType = {
    'bill': [issuer, amount, dueDate, periodMonth, refNumber],
    'cnic': [name, number, issueDate, expiryDate],
    'passport': [name, number, issueDate, expiryDate],
    'visa': [name, number, issueDate, expiryDate],
    'license': [name, number, issueDate, expiryDate],
    'fee_voucher': [institution, studentName, amount, dueDate, refNumber],
    'receipt': [issuer, amount, issueDate],
    'prescription': [issueDate, doctor],
    'report': [issueDate, issuer],
    'degree': [institution, name, issueDate],
    'certificate': [institution, name, issueDate],
    'warranty': [product, startDate, endDate],
    'policy': [product, number, startDate, endDate],
    'agreement': [startDate, endDate],
    'other': <String>[],
  };

  static bool isDate(String f) =>
      f == dueDate ||
      f == issueDate ||
      f == expiryDate ||
      f == startDate ||
      f == endDate;
}

/// A label the user taught us for an issuer: the value of [field] follows
/// [label] on its line (per-issuer learning, AC6).
class IssuerHint {
  const IssuerHint(this.field, this.label);
  final String field;
  final String label;
}

class Extracted {
  const Extracted(this.value, this.confidence);
  final String value;
  final double confidence;
}

// ─────────────────────────────── Dates ─────────────────────────────────────

const _monthNames = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

int _year(String y) {
  final n = int.parse(y);
  return n < 100 ? 2000 + n : n;
}

DateTime? _valid(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1950 || y > 2100) return null;
  final date = DateTime(y, m, d);
  return date.month == m ? date : null; // reject 31 Feb etc.
}

final _numericDate = RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\b');
final _dayMonthName = RegExp(
  r'\b(\d{1,2})[\s\-/]*([A-Za-z]{3})[A-Za-z]*[\s,\-/]*(\d{2,4})\b',
);
final _monthNameDay = RegExp(
  r'\b([A-Za-z]{3})[A-Za-z]*\s+(\d{1,2}),?\s+(\d{4})\b',
);
final _isoDate = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b');

/// First date in [s] (day-first, as printed in Pakistan).
DateTime? parseDate(String s) {
  final t = normalizeDigits(s);
  final candidates = <(int, DateTime)>[];
  for (final m in _isoDate.allMatches(t)) {
    final d = _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (d != null) candidates.add((m.start, d));
  }
  for (final m in _numericDate.allMatches(t)) {
    final d = _valid(_year(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (d != null) candidates.add((m.start, d));
  }
  for (final m in _dayMonthName.allMatches(t)) {
    final month = _monthNames[m[2]!.toLowerCase()];
    if (month == null) continue;
    final d = _valid(_year(m[3]!), month, int.parse(m[1]!));
    if (d != null) candidates.add((m.start, d));
  }
  for (final m in _monthNameDay.allMatches(t)) {
    final month = _monthNames[m[1]!.toLowerCase()];
    if (month == null) continue;
    final d = _valid(_year(m[3]!), month, int.parse(m[2]!));
    if (d != null) candidates.add((m.start, d));
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.$1.compareTo(b.$1));
  return candidates.first.$2;
}

final _monthYear = RegExp(r'\b([A-Za-z]{3})[A-Za-z]*[\s\-/,]*(\d{2,4})\b');
final _numMonthYear = RegExp(r'\b(\d{1,2})[/-](\d{4})\b');

/// A billing month like "NOV-26", "November 2026" or "11/2026" → 1st of it.
DateTime? parseMonth(String s) {
  final t = normalizeDigits(s);
  for (final m in _monthYear.allMatches(t)) {
    final month = _monthNames[m[1]!.toLowerCase()];
    if (month != null) return DateTime(_year(m[2]!), month);
  }
  final n = _numMonthYear.firstMatch(t);
  if (n != null) {
    final month = int.parse(n[1]!);
    if (month >= 1 && month <= 12) return DateTime(int.parse(n[2]!), month);
  }
  return null;
}

// ────────────────────────────── Helpers ────────────────────────────────────

class _Doc {
  _Doc(String raw)
    : text = _cleanOcr(raw),
      lines = _cleanOcr(raw)
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

  final String text;
  final List<String> lines;

  /// The rest of the first line containing any of [labels] (after the
  /// label), plus the following line as a fallback.
  List<String> after(List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      for (final label in labels) {
        final m = _labelPattern(label).firstMatch(lines[i]);
        if (m == null) continue;
        final rest = lines[i].substring(m.end);
        return [
          rest.replaceFirst(RegExp(r'^[\s:#.\-]+'), ''),
          if (i + 1 < lines.length) lines[i + 1],
        ];
      }
    }
    return const [];
  }

  DateTime? dateAfter(List<String> labels) {
    for (final part in after(labels)) {
      final d = parseDate(part);
      if (d != null) return d;
    }
    return null;
  }

  int? amountAfter(List<String> labels) {
    for (final part in after(labels)) {
      // Skip dates and long reference numbers sitting next to the label.
      final cleaned = part
          .replaceAll(_numericDate, ' ')
          .replaceAll(_dayMonthName, ' ');
      final m = RegExp(
        r'(?:rs\.?|pkr)?\s*(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d{1,7}(?:\.\d{1,2})?)\b',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (m != null) {
        final v = Money.parseMinor(m[1]!);
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  String? tokenAfter(List<String> labels, {RegExp? shape}) {
    final pattern =
        shape ?? RegExp(r'[A-Z0-9][A-Z0-9\-/]{4,}', caseSensitive: false);
    for (final part in after(labels)) {
      final m = pattern.firstMatch(part);
      if (m != null) return m[0]!.toUpperCase();
    }
    return null;
  }

  /// A reference / account number, keeping space-separated groups such as
  /// LESCO's "08 11111 2233445 U" whole (found in device QA: the first
  /// 5+ character group alone was taken, so meters in one subdivision
  /// collided). Later groups must hold a digit or be a single letter, so a
  /// following word ("Name") is never swallowed. Spaces are normalised.
  String? refAfter(List<String> labels) {
    final pattern = RegExp(
      r'[A-Z0-9][A-Z0-9\-/]*(?: +(?:[A-Z\-/]*\d[A-Z0-9\-/]*|[A-Z]\b))*',
      caseSensitive: false,
    );
    for (final part in after(labels)) {
      for (final m in pattern.allMatches(part)) {
        final v = m[0]!.trim().replaceAll(RegExp(r' +'), ' ');
        if (v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length >= 5 &&
            RegExp(r'\d').hasMatch(v)) {
          return v.toUpperCase();
        }
      }
    }
    return null;
  }

  String? phraseAfter(List<String> labels) {
    for (final part in after(labels)) {
      final cleaned = part
          .replaceAll(RegExp(r'[^A-Za-z .\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length >= 3) return _titleCase(cleaned);
    }
    return null;
  }

  /// First line containing any of [words] (for institutions etc.).
  String? lineWith(List<String> words) {
    for (final l in lines) {
      final lower = l.toLowerCase();
      if (words.any(lower.contains)) return _titleCase(l);
    }
    return null;
  }
}

/// Undoes common OCR slips that break amounts: "R5." / "R$" for "Rs.".
String _cleanOcr(String raw) => normalizeDigits(raw).replaceAllMapped(
  RegExp(r'\bR[s5$]\.?(?=\s*\d)', caseSensitive: false),
  (_) => 'Rs. ',
);

/// Letters OCR commonly confuses, so "Due Dale" still matches "due date"
/// and "Payab1e" matches "payable".
const _confusable = {
  'a': '[a@4]',
  'b': '[b6]',
  'e': '[e3c]',
  'g': '[g9]',
  'i': '[il1|!]',
  'l': '[l1i|t]',
  'o': '[o0]',
  's': r'[s5$]',
  't': '[tl+]',
  'z': '[z2]',
};

final _labelCache = <String, RegExp>{};

/// Case-insensitive, OCR-tolerant matcher for a label: confusable letters,
/// flexible spacing, optional dots.
RegExp _labelPattern(String label) => _labelCache.putIfAbsent(label, () {
  final buf = StringBuffer();
  for (final ch in label.toLowerCase().split('')) {
    if (ch == ' ') {
      buf.write(r'\s*');
    } else if (ch == '.') {
      buf.write(r'\.?');
    } else {
      buf.write(_confusable[ch] ?? RegExp.escape(ch));
    }
  }
  return RegExp(buf.toString(), caseSensitive: false);
});

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) {
      if (w.length <= 3 &&
          w == w.toUpperCase() &&
          RegExp('[A-Z]').hasMatch(w)) {
        return w; // keep acronyms like PTCL, ABC
      }
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    })
    .join(' ');

// ───────────────────────────── Extraction ──────────────────────────────────

const _dueLabels = ['due date', 'last date', 'pay by', 'payable by', 'due on'];
const _amountLabels = [
  'payable within due date',
  'amount payable',
  'total payable',
  'net payable',
  'amount due',
  'total amount',
  'grand total',
  'total fee',
  'total',
  'amount',
];
const _refLabels = [
  'reference no',
  'ref no',
  'ref. no',
  'consumer no',
  'consumer id',
  'account no',
  'account number',
  'customer id',
  'challan no',
  'voucher no',
];
const _issueLabels = [
  'date of issue',
  'issue date',
  'issued on',
  'dated',
  'date',
];
const _expiryLabels = [
  'date of expiry',
  'expiry date',
  'expiry',
  'valid until',
  'valid till',
  'valid upto',
  'expires',
];

/// Extracts the fields for [type]. [hints] are per-issuer labels learned
/// from the user's corrections; they win over the built-in labels.
Map<String, Extracted> extractFields(
  String type,
  String rawText, {
  List<IssuerHint> hints = const [],
}) {
  final doc = _Doc(rawText);
  final out = <String, Extracted>{};
  void put(String field, String? value, double confidence) {
    if (value != null && value.trim().isNotEmpty) {
      out[field] = Extracted(value.trim(), confidence);
    }
  }

  String? iso(DateTime? d) => d == null ? null : _iso(d);

  // Learned labels first (AC6).
  for (final h in hints) {
    if (Fields.isDate(h.field)) {
      put(h.field, iso(doc.dateAfter([h.label])), 0.95);
    } else if (h.field == Fields.amount) {
      put(h.field, doc.amountAfter([h.label])?.toString(), 0.95);
    } else if (h.field == Fields.periodMonth) {
      final parts = doc.after([h.label]);
      put(h.field, iso(parts.map(parseMonth).nonNulls.firstOrNull), 0.95);
    } else {
      put(h.field, doc.tokenAfter([h.label]), 0.95);
    }
  }
  void fill(String field, String? value, double confidence) {
    if (!out.containsKey(field)) put(field, value, confidence);
  }

  switch (type) {
    case 'bill':
      fill(Fields.issuer, findIssuer(doc.text), 0.9);
      fill(Fields.amount, doc.amountAfter(_amountLabels)?.toString(), 0.8);
      fill(Fields.dueDate, iso(doc.dateAfter(_dueLabels)), 0.85);
      final month = doc
          .after(['bill month', 'billing month', 'bill period', 'month'])
          .map(parseMonth)
          .nonNulls
          .firstOrNull;
      fill(Fields.periodMonth, iso(month), 0.8);
      fill(Fields.refNumber, doc.refAfter(_refLabels), 0.8);
    case 'cnic' || 'passport' || 'visa' || 'license':
      fill(Fields.name, doc.phraseAfter(['name']), 0.7);
      final number = switch (type) {
        'cnic' => RegExp(r'\b\d{5}-\d{7}-\d\b').firstMatch(doc.text)?[0],
        'passport' =>
          doc.tokenAfter([
                'passport no',
                'passport number',
              ], shape: RegExp(r'[A-Z]{1,2}\d{6,8}')) ??
              RegExp(r'\b[A-Z]{2}\d{7}\b').firstMatch(doc.text)?[0],
        _ => doc.tokenAfter(['licence no', 'license no', 'visa no', 'number']),
      };
      fill(Fields.number, number, 0.85);
      fill(Fields.issueDate, iso(doc.dateAfter(_issueLabels)), 0.75);
      fill(Fields.expiryDate, iso(doc.dateAfter(_expiryLabels)), 0.85);
    case 'fee_voucher':
      fill(
        Fields.institution,
        doc.lineWith([
          'school',
          'college',
          'university',
          'academy',
          'institute',
        ]),
        0.75,
      );
      fill(
        Fields.studentName,
        doc.phraseAfter(['student name', 'name of student', 'student', 'name']),
        0.7,
      );
      fill(Fields.amount, doc.amountAfter(_amountLabels)?.toString(), 0.8);
      fill(Fields.dueDate, iso(doc.dateAfter(_dueLabels)), 0.85);
      fill(Fields.refNumber, doc.refAfter(_refLabels), 0.75);
    case 'receipt':
      fill(
        Fields.issuer,
        doc.lines.isEmpty ? null : _titleCase(doc.lines.first),
        0.5,
      );
      fill(Fields.amount, doc.amountAfter(_amountLabels)?.toString(), 0.75);
      fill(
        Fields.issueDate,
        iso(doc.dateAfter(_issueLabels) ?? parseDate(doc.text)),
        0.7,
      );
    case 'prescription':
      fill(
        Fields.issueDate,
        iso(doc.dateAfter(_issueLabels) ?? parseDate(doc.text)),
        0.7,
      );
      final dr = RegExp(
        r'\bDr\.?\s+([A-Z][A-Za-z.]*(?:\s+[A-Z][A-Za-z.]*){0,3})',
      ).firstMatch(doc.text);
      fill(Fields.doctor, dr == null ? null : 'Dr. ${dr[1]!.trim()}', 0.75);
    case 'report':
      fill(
        Fields.issueDate,
        iso(doc.dateAfter(['report date', ..._issueLabels])),
        0.7,
      );
      fill(
        Fields.issuer,
        doc.lineWith(['laboratory', 'lab', 'diagnostic', 'hospital']),
        0.6,
      );
    case 'degree' || 'certificate':
      fill(
        Fields.institution,
        doc.lineWith(['university', 'institute', 'college', 'board']),
        0.7,
      );
      fill(
        Fields.name,
        doc.phraseAfter([
          'certify that',
          'conferred upon',
          'awarded to',
          'name',
        ]),
        0.6,
      );
      fill(
        Fields.issueDate,
        iso(doc.dateAfter(_issueLabels) ?? parseDate(doc.text)),
        0.6,
      );
    case 'warranty' || 'policy':
      fill(
        Fields.product,
        doc.phraseAfter(['product', 'model', 'item', 'plan', 'vehicle']),
        0.65,
      );
      if (type == 'policy') {
        fill(
          Fields.number,
          doc.tokenAfter(['policy no', 'policy number']),
          0.8,
        );
      }
      fill(
        Fields.startDate,
        iso(
          doc.dateAfter([
            'date of purchase',
            'purchase date',
            'start date',
            'commencement',
            'effective from',
          ]),
        ),
        0.75,
      );
      fill(
        Fields.endDate,
        iso(
          doc.dateAfter([
            'warranty until',
            'warranty till',
            'end date',
            'maturity',
            ..._expiryLabels,
          ]),
        ),
        0.8,
      );
    case 'agreement':
      fill(
        Fields.startDate,
        iso(
          doc.dateAfter(['commencing', 'start date', 'effective from', 'from']),
        ),
        0.6,
      );
      fill(
        Fields.endDate,
        iso(doc.dateAfter(['ending', 'end date', 'until', 'to'])),
        0.6,
      );
  }
  out.removeWhere((k, _) => !(Fields.forType[type] ?? const []).contains(k));
  return out;
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ─────────────────────────── Titles & folders ──────────────────────────────

/// English type names, used in auto-titles (stored as document titles).
const _typeNamesEn = {
  'cnic': 'CNIC',
  'passport': 'Passport',
  'visa': 'Visa',
  'license': 'Driving licence',
  'bill': 'Bill',
  'fee_voucher': 'Fee voucher',
  'receipt': 'Receipt',
  'prescription': 'Prescription',
  'report': 'Lab report',
  'degree': 'Degree',
  'certificate': 'Certificate',
  'warranty': 'Warranty',
  'policy': 'Insurance policy',
  'agreement': 'Agreement',
  'other': 'Document',
};

/// Display name of a document type, in the app's language.
String typeName(String type) {
  final l = l10nNow;
  return switch (type) {
    'cnic' => l.cpTypeCnic,
    'passport' => l.cpTypePassport,
    'visa' => l.cpTypeVisa,
    'license' => l.cpTypeLicense,
    'bill' => l.cpTypeBill,
    'fee_voucher' => l.cpTypeFeeVoucher,
    'receipt' => l.cpTypeReceipt,
    'prescription' => l.cpTypePrescription,
    'report' => l.cpTypeReport,
    'degree' => l.cpTypeDegree,
    'certificate' => l.cpTypeCertificate,
    'warranty' => l.cpTypeWarranty,
    'policy' => l.cpTypePolicy,
    'agreement' => l.cpTypeAgreement,
    _ => l.cpTypeOther,
  };
}

String _typeNameEn(String type) => _typeNamesEn[type] ?? 'Document';

/// Auto-title (features spec §1.2): "K-Electric Bill — Nov 2026",
/// "Passport — Ali Khan", "Unclassified · 8 Nov 2026".
String autoTitle(String type, Map<String, String> fields, DateTime now) {
  String monthLabel(String iso) {
    final p = iso.split('-').map(int.parse).toList();
    final d = DateTime(p[0], p[1]);
    return '${shortMonth(d)} ${d.year}';
  }

  switch (type) {
    case 'other':
      return 'Unclassified · ${now.day} ${shortMonth(now)} ${now.year}';
    case 'bill':
      final issuer = fields[Fields.issuer];
      final month = fields[Fields.periodMonth] ?? fields[Fields.dueDate];
      return [
        '${issuer ?? ''} Bill'.trim(),
        if (month != null) monthLabel(month),
      ].join(' — ');
    case 'fee_voucher':
      final who = fields[Fields.studentName];
      return who == null ? 'Fee voucher' : '$who — school fee';
    default:
      final who =
          fields[Fields.name] ??
          fields[Fields.institution] ??
          fields[Fields.product] ??
          fields[Fields.doctor];
      return who == null ? _typeNameEn(type) : '${_typeNameEn(type)} — $who';
  }
}

/// Folder kind for a type (PBI-004 grooming).
String? folderKindFor(String type) => switch (type) {
  'cnic' || 'passport' || 'visa' || 'license' => 'identity',
  'degree' || 'certificate' || 'fee_voucher' => 'education',
  'prescription' || 'report' => 'medical',
  'bill' || 'receipt' => 'bills',
  'warranty' || 'policy' => 'insurance',
  'agreement' => 'property',
  _ => null,
};

/// Learns per-issuer labels from earlier corrections: for each corrected
/// field, the text in front of the corrected value on its OCR line.
List<IssuerHint> learnHints(
  Iterable<({String field, String value, String ocrText})> corrections,
) {
  final hints = <IssuerHint>[];
  for (final c in corrections) {
    final text = normalizeDigits(c.ocrText);
    final needles = <String>{c.value};
    if (c.field == Fields.amount) {
      final minor = int.tryParse(c.value);
      if (minor != null) {
        needles
          ..add(Money.format(minor).replaceFirst('Rs ', ''))
          ..add((minor ~/ 100).toString());
      }
    }
    if (Fields.isDate(c.field) || c.field == Fields.periodMonth) continue;
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final hit = needles.where((n) => n.isNotEmpty && line.contains(n));
      if (hit.isEmpty) continue;
      final label = line
          .substring(0, line.indexOf(hit.first))
          .replaceAll(RegExp(r'(rs\.?|pkr)\s*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[\s:#.\-]+$'), '')
          .trim();
      if (label.length >= 3) hints.add(IssuerHint(c.field, label));
      break;
    }
  }
  return hints;
}
