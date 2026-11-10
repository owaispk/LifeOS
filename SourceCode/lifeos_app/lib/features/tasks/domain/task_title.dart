// Shaping a task title and its notes out of free text — pure Dart.
//
// Shared by the live quick-add preview (PBI-010) and by text shared in
// from another app (PBI-034), so both strip the same words the same way.
import 'nl_parser.dart';

/// Longest title taken from shared text; the rest goes to the notes.
const sharedTitleLimit = 80;

final _glue = RegExp(
  r'^\s*(to|on|at|by)\s+|\s+(on|at|by|ko|due|due\s+(on|by))\s*$',
  caseSensitive: false,
);

/// [source] with each of [remove] taken out once, tidied and capitalised.
/// Falls back to [source] when nothing is left.
String titleFrom(String source, Iterable<String> remove) {
  var t = ' $source ';
  for (final words in remove) {
    if (words.isEmpty) continue;
    final i = t.toLowerCase().indexOf(words.toLowerCase());
    if (i >= 0) t = '${t.substring(0, i)} ${t.substring(i + words.length)}';
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(_glue, ' ').trim();
  if (t.isEmpty) t = source.trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// The words [parsed] recognised, as they appeared. The domain hint stays
/// in the title ("Pay the bill" should keep "bill"), and anything in
/// [dropped] — a chip the user tapped away — goes back.
Iterable<String> matchedWords(
  ParsedTask parsed, {
  Set<ParsedPart> dropped = const {},
}) => [
  for (final e in parsed.matched.entries)
    if (e.key != ParsedPart.domain && !dropped.contains(e.key)) e.value,
];

/// The title for text shared in (PBI-034 AC3): the first line with
/// anything on it, minus what the parser recognised, clipped at a word
/// boundary. Parsing itself still runs over the whole text, because a
/// date or an amount is often further down a forwarded message.
String sharedTaskTitle(String text, ParsedTask parsed) {
  final line = text
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  final title = titleFrom(line, matchedWords(parsed));
  if (title.length <= sharedTitleLimit) return title;
  final cut = title.substring(0, sharedTitleLimit);
  final lastSpace = cut.lastIndexOf(' ');
  return '${(lastSpace > sharedTitleLimit ~/ 2 ? cut.substring(0, lastSpace) : cut).trimRight()}…';
}

/// What the title could not carry. Text shared in keeps all of itself, so
/// a forwarded message loses nothing; a typed task keeps the amount the
/// parser took out of its title (PBI-034).
String? taskNotes({
  required String title,
  String? sharedText,
  String? amount,
}) {
  final full = sharedText?.trim() ?? '';
  if (full.isNotEmpty && full != title) return full;
  if (amount != null && amount.isNotEmpty && !title.contains(amount)) {
    return amount;
  }
  return null;
}
