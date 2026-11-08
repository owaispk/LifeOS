// Rule-based document classifier (PBI-004) — pure Dart, offline.
import '../../../core/text.dart';
import 'issuers.dart';

/// Below this, the user picks the type (AC1).
const confidenceThreshold = 0.7;

const docTypes = [
  'cnic',
  'passport',
  'visa',
  'license',
  'bill',
  'fee_voucher',
  'receipt',
  'prescription',
  'report',
  'degree',
  'certificate',
  'warranty',
  'policy',
  'agreement',
  'other',
];

class _Signal {
  const _Signal(this.pattern, this.weight);
  final Pattern pattern;
  final double weight;
}

_Signal _k(String keyword, double w) => _Signal(keyword, w);
_Signal _r(String regex, double w) => _Signal(RegExp(regex), w);

/// Evidence per type. Strings match case-insensitively as substrings;
/// regexes run on the lower-cased text unless they contain upper-case
/// classes (then on the original).
final Map<String, List<_Signal>> _signals = {
  'cnic': [
    _k('computerized national identity card', 4),
    _k('national identity card', 3),
    _k('nadra', 2),
    _k('identity number', 2),
    _r(r'\b\d{5}-\d{7}-\d\b', 3),
  ],
  'passport': [
    _k('passport', 3),
    _k('passport no', 2),
    _k('place of birth', 1),
    _k('nationality', 1),
    _r(r'p<[a-z]{3}', 3), // MRZ line
  ],
  'visa': [
    _k('visa', 3),
    _k('visa type', 2),
    _k('entries', 1),
    _k('duration of stay', 2),
  ],
  'license': [
    _k('driving licence', 4),
    _k('driving license', 4),
    _k('licence no', 2),
    _k('license no', 2),
    _k('vehicle class', 2),
  ],
  'bill': [
    _k('bill month', 3),
    _k('billing month', 3),
    _k('consumer', 2),
    _k('units', 1),
    _k('kwh', 2),
    _k('meter', 1),
    _k('payable within due date', 3),
    _k('amount payable', 2),
    _k('electricity', 2),
    _k('gas bill', 2),
    _k('internet', 1),
    _k('due date', 1),
    _k('bill', 1),
  ],
  'fee_voucher': [
    _k('fee voucher', 4),
    _k('fee challan', 4),
    _k('challan', 2),
    _k('tuition', 2),
    _k('student', 2),
    _k('roll no', 2),
    _k('class:', 1),
    _k('school', 1),
    _k('college', 1),
    _k('admission', 1),
  ],
  'receipt': [
    _k('receipt', 3),
    _k('cash memo', 3),
    _k('thank you', 1),
    _k('qty', 1),
    _k('subtotal', 1),
    _k('paid', 1),
  ],
  'prescription': [
    _k('prescription', 3),
    _k('rx', 2),
    _k('tab.', 2),
    _k('cap.', 2),
    _k('syrup', 1),
    _k('mg', 1),
    _k('twice a day', 2),
    _k('once a day', 2),
    _k('after meal', 1),
    _k('clinic', 1),
  ],
  'report': [
    _k('laboratory', 3),
    _k('lab report', 3),
    _k('reference range', 3),
    _k('specimen', 2),
    _k('pathology', 2),
    _k('test name', 2),
    _k('result', 1),
  ],
  'degree': [
    _k('bachelor', 3),
    _k('master of', 3),
    _k('degree', 3),
    _k('conferred', 2),
    _k('university', 1),
  ],
  'certificate': [
    _k('certificate', 3),
    _k('this is to certify', 3),
    _k('awarded', 1),
    _k('successfully completed', 2),
  ],
  'warranty': [
    _k('warranty', 4),
    _k('guarantee', 2),
    _k('serial no', 2),
    _k('model', 1),
    _k('date of purchase', 1),
  ],
  'policy': [
    _k('insurance', 2),
    _k('policy no', 3),
    _k('policy number', 3),
    _k('insured', 2),
    _k('sum assured', 3),
    _k('premium', 2),
  ],
  'agreement': [
    _k('agreement', 3),
    _k('tenancy', 2),
    _k('landlord', 2),
    _k('tenant', 2),
    _k('witness', 1),
    _k('hereby', 1),
  ],
};

class Classification {
  const Classification(this.type, this.confidence, this.scores);

  final String type;
  final double confidence;
  final Map<String, double> scores;

  bool get isConfident => confidence >= confidenceThreshold;
}

/// Classifies OCR text. Empty or unrecognisable text → `other` with 0
/// confidence ("Unclassified", AC5).
Classification classify(String rawText) {
  final text = normalizeDigits(rawText);
  final lower = text.toLowerCase();
  final scores = <String, double>{};

  for (final entry in _signals.entries) {
    var score = 0.0;
    for (final s in entry.value) {
      final p = s.pattern;
      final hit = p is RegExp
          ? p.hasMatch(lower) || p.hasMatch(text)
          : lower.contains(p as String);
      if (hit) score += s.weight;
    }
    if (score > 0) scores[entry.key] = score;
  }

  // A known utility/telecom issuer is strong evidence for a bill.
  if (findIssuer(text) != null) {
    scores['bill'] = (scores['bill'] ?? 0) + 3;
  }

  if (scores.isEmpty) return const Classification('other', 0, {});

  final ranked = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = ranked.first;
  final second = ranked.length > 1 ? ranked[1].value : 0.0;
  final total = scores.values.fold<double>(0, (a, b) => a + b);

  // Share of the evidence, plus how clearly the winner leads, scaled by
  // how much evidence there is at all.
  final share = top.value / total;
  final lead = (top.value - second) / top.value;
  final strength = (top.value / 6).clamp(0.0, 1.0);
  final confidence = ((share + lead) / 2 * 0.6 + strength * 0.4).clamp(
    0.0,
    1.0,
  );

  return Classification(top.key, confidence, scores);
}
