// PBI-035 AC8 / Definition of Done: no religious or culture-specific words
// in default UI strings, in any language. Cultural content may only appear
// behind an explicit user choice — the opt-in greeting styles below.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strings that only show when the user picks them (My Profile → Greeting).
const optIn = {
  'hmGreetSalam', 'hmGreetSalamName', 'setGreetingSalam',
  'hmGreetNamaste', 'hmGreetNamasteName', 'setGreetingNamaste',
};

/// Words that assume a faith or culture. Extend as new content lands.
/// (Not listed: جمعہ / "jumma" — it is simply Urdu for Friday, the
/// weekday name every Urdu speaker uses.)
final banned = RegExp(
  r'\bsalam|salaam|assalam|namaste|allah|insha|masha|bismillah|ramadan|'
  r'ramzan|\beid\b|mosque|masjid|namaz|christmas|diwali|church|temple|'
  r'🕌|🛐|☪|✝|🕉|'
  r'سلام|اللہ|رمضان|عید|نماز|مسجد|نمستے',
  caseSensitive: false,
);

void main() {
  for (final lang in ['en', 'ur']) {
    test('$lang: default strings are faith- and culture-neutral', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      final offenders = [
        for (final e in arb.entries)
          if (!e.key.startsWith('@') &&
              !optIn.contains(e.key) &&
              e.value is String &&
              banned.hasMatch(e.value as String))
            '${e.key}: ${e.value}',
      ];
      expect(offenders, isEmpty);
    });
  }
}
