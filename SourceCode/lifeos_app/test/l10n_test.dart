// PBI-025 AC2: no hard-coded user-facing strings in lib/, and every key has
// both English and Urdu.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _args =
    'label|title|tooltip|hintText|labelText|helperText|message|actionLabel|'
    'semanticsLabel|semanticLabel|subtitle|helpText|prefixText|suffixText|'
    'errorText|counterText|deleteButtonTooltipMessage|confirmText|cancelText';
const _str = r'''(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")''';
final _pattern = RegExp(
  '(?:\\bText\\(\\s*|\\b(?:$_args):\\s*(?:const\\s+)?(?:Text\\(\\s*)?)'
  '($_str(?:\\s*$_str)*)',
);

/// A literal counts when it has letters outside `${...}` interpolations
/// (emoji, digits and punctuation alone are fine).
bool _hasWords(String literal) {
  final body = literal
      .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '')
      .replaceAll(RegExp(r'''^['"]|['"]$'''), '');
  return RegExp(r'[A-Za-z؀-ۿ]').hasMatch(body);
}

void main() {
  test('AC2: no hard-coded user-facing strings in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll('\\', '/');
      if (rel.contains('lib/l10n/') || rel.endsWith('.g.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in _pattern.allMatches(src)) {
        if (_hasWords(m[1]!)) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('$rel:$line ${m[1]}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(40).join('\n'));
  });

  test('every key has English and Urdu, with the same placeholders', () {
    Map<String, dynamic> load(String loc) =>
        jsonDecode(File('lib/l10n/app_$loc.arb').readAsStringSync())
            as Map<String, dynamic>;
    final en = load('en');
    final ur = load('ur');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
    expect(ur.keys.where((k) => !k.startsWith('@')).toSet(), keys);
    Set<String> holders(String s) => {
      for (final m in RegExp(r'\{(\w+)').allMatches(s)) m[1]!,
    };
    for (final k in keys) {
      // Plural branches hold translated words in braces: compare the
      // selector only.
      if ((en[k] as String).contains(', plural,')) {
        Set<String> plurals(String s) => {
          for (final m in RegExp(r'\{(\w+),\s*plural').allMatches(s)) m[1]!,
        };
        expect(
          plurals(ur[k] as String),
          plurals(en[k] as String),
          reason: 'plural selector of $k',
        );
        continue;
      }
      expect(
        holders(ur[k] as String),
        holders(en[k] as String),
        reason: 'placeholders of $k',
      );
      expect((ur[k] as String).trim(), isNotEmpty, reason: k);
    }
  });
}
