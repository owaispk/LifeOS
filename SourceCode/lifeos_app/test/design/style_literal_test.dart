// Design system §3: feature code styles through tokens and the theme — no
// colour, font-size or corner-radius literals.
//
// The screens are restyled slice by slice (Design/design-system.md Part 5),
// so this is a ratchet: each count may only go down. When a slice removes
// literals, lower its number here. The end state is zero for all three.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Literal lines left in `lib/features` (measured 2026-11-11, slice 0).
/// `colour` includes the 14 in `money/ui/category_colors.dart`, a
/// deliberate palette that moves to `core/theme` in the Money slice.
const _allowed = {'colour': 23, 'font size': 24, 'radius': 13};

final _patterns = {
  'colour': RegExp(r'Color\(0x|Colors\.(?!transparent\b)[a-z]'),
  'font size': RegExp(r'fontSize:\s*\d'),
  'radius': RegExp(r'(BorderRadius|Radius)\.circular\(\s*\d'),
};

void main() {
  final found = {for (final k in _patterns.keys) k: <String>[]};
  for (final f in Directory('lib/features').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final p in _patterns.entries) {
        if (p.value.hasMatch(lines[i])) {
          found[p.key]!.add('${f.path}:${i + 1} ${lines[i].trim()}');
        }
      }
    }
  }

  for (final kind in _patterns.keys) {
    test('no new $kind literals in lib/features', () {
      expect(
        found[kind]!.length,
        lessThanOrEqualTo(_allowed[kind]!),
        reason:
            'Use a token or the theme (core/theme) instead of a literal.\n'
            '${found[kind]!.join('\n')}',
      );
    });

    test('the $kind allowance matches what is left', () {
      expect(
        found[kind]!.length,
        _allowed[kind],
        reason:
            'Literals were removed: lower "$kind" in _allowed to '
            '${found[kind]!.length} so they cannot come back.',
      );
    });
  }
}
