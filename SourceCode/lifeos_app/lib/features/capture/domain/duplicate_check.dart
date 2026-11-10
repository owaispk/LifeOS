// Duplicate detection for captures (PBI-003 AC7) — pure Dart.
//
// The 64-bit image hash alone is too coarse for documents: a mostly white
// page shrinks to its layout, so this month's bill and last month's bill
// from the same company hash almost the same. When both documents have OCR
// text, the text has to match too, and the numbers (amounts, dates,
// reference and meter readings) most of all, because those are what change
// between two documents built from one template.
import 'image_checks.dart';

/// Without OCR text on both sides, the image hashes must be this close.
const strictDuplicateDistance = 2;

/// Share of number tokens two scans of the same paper have in common.
const minNumberOverlap = 0.8;

/// Share of word tokens two scans of the same paper have in common.
const minWordOverlap = 0.6;

/// Used when a page has too few numbers to judge by them.
const minWordOverlapNoNumbers = 0.85;

/// Whether a new capture duplicates a stored one: page-1 image hashes
/// ([newHash], [oldHash]) and OCR text ([newText], [oldText], may be empty).
bool isDuplicateCapture({
  required String newHash,
  required String oldHash,
  required String newText,
  required String oldText,
}) {
  final distance = hammingDistance(newHash, oldHash);
  if (newText.trim().isEmpty || oldText.trim().isEmpty) {
    return distance <= strictDuplicateDistance;
  }
  return distance <= duplicateMaxDistance && sameText(newText, oldText);
}

/// True when two OCR texts read the same paper: the numbers match closely
/// and the words mostly match. OCR noise between two scans is tolerated.
bool sameText(String a, String b) {
  final ta = _tokens(a), tb = _tokens(b);
  if (ta.numbers.length >= 3 && tb.numbers.length >= 3) {
    return overlap(ta.numbers, tb.numbers) >= minNumberOverlap &&
        overlap(ta.words, tb.words) >= minWordOverlap;
  }
  return overlap(ta.words, tb.words) >= minWordOverlapNoNumbers;
}

/// Jaccard overlap of two token sets (1 = identical, 0 = nothing shared).
double overlap(Set<String> a, Set<String> b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final shared = a.intersection(b).length;
  return shared / (a.length + b.length - shared);
}

final _thousands = RegExp(r'(?<=\d)[,\s](?=\d{3}\b)');
final _edges = RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);
final _digit = RegExp(r'\d');

({Set<String> numbers, Set<String> words}) _tokens(String text) {
  final numbers = <String>{}, words = <String>{};
  // "4,850" and "4 850" are one number; dates like 14-11-2026 stay whole.
  final flat = text.toLowerCase().replaceAll(_thousands, '');
  for (final raw in flat.split(RegExp(r'\s+'))) {
    final t = raw.replaceAll(_edges, '');
    if (t.length < 2) continue;
    (_digit.hasMatch(t) ? numbers : words).add(t);
  }
  return (numbers: numbers, words: words);
}
