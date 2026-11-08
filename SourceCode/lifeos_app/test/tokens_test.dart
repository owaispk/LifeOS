// PBI-001 AC4: design tokens live in one place and follow the spec.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/theme/tokens.dart';

void main() {
  test('every life domain has an accent colour', () {
    for (final d in LifeDomain.values) {
      expect(Tokens.domainColors.containsKey(d), isTrue, reason: d.name);
    }
  });

  test('score colours: <40 red, 40–69 amber, ≥70 green', () {
    expect(Tokens.scoreColor(0), Tokens.scoreLow);
    expect(Tokens.scoreColor(39), Tokens.scoreLow);
    expect(Tokens.scoreColor(40), Tokens.scoreMid);
    expect(Tokens.scoreColor(69), Tokens.scoreMid);
    expect(Tokens.scoreColor(70), Tokens.scoreHigh);
    expect(Tokens.scoreColor(100), Tokens.scoreHigh);
  });

  test('accessibility sizes', () {
    expect(Tokens.minTouchTarget, greaterThanOrEqualTo(48));
    expect(Tokens.bodyFontSize, 16);
  });
}
