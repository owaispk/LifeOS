// PBI-002 AC6: amounts convert to/from minor units with no rounding errors.
// PBI-035: the display symbol is the user's.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/money.dart';
import 'package:lifeos_app/core/region.dart';

void main() {
  group('parseMinor', () {
    final cases = <String, int?>{
      'Rs 4,850': 485000,
      'Rs. 1,250.50': 125050,
      'PKR 12,000': 1200000,
      '4850': 485000,
      'Rs 0.5': 50,
      'Rs 0.05': 5,
      'Rs 61,500 total': 6150000,
      '-250': -25000,
      '۴۸۵۰': 485000, // Urdu digits
      '٤٬٨٥٠': 485000, // Arabic-Indic digits + Arabic thousands separator
      'no amount here': null,
      '': null,
    };
    cases.forEach((input, expected) {
      test('"$input" → $expected', () {
        expect(Money.parseMinor(input), expected);
      });
    });

    test('0.1 + 0.2 style inputs stay exact', () {
      expect(
        Money.parseMinor('0.10')! + Money.parseMinor('0.20')!,
        Money.parseMinor('0.30'),
      );
    });
  });

  group('format', () {
    final cases = <int, String>{
      485000: 'Rs 4,850',
      125050: 'Rs 1,250.50',
      5: 'Rs 0.05',
      0: 'Rs 0',
      100: 'Rs 1',
      6150000: 'Rs 61,500',
      12345678900: 'Rs 123,456,789',
      -25000: '-Rs 250',
    };
    cases.forEach((minor, expected) {
      test('$minor → "$expected"', () {
        expect(Money.format(minor), expected);
      });
    });

    // PBI-035: the symbol is the user's (display only, never converted).
    test("uses the user's currency symbol", () {
      for (final (symbol, expected) in [
        (r'$', r'$ 19.99'),
        ('₹', '₹ 19.99'),
        ('AED', 'AED 19.99'),
      ]) {
        AppRegion.current = resolveRegion(
          const Locale('en', 'PK'),
          symbol: symbol,
        );
        expect(Money.format(1999), expected);
        expect(Money.prefix, '$symbol ');
      }
      expect(Money.format(-25000), '-AED 250');
    });

    test('formatPlain has no symbol (input fields show it as a prefix)', () {
      expect(Money.formatPlain(485000), '4,850');
      expect(Money.formatPlain(125050), '1,250.50');
      expect(Money.formatPlain(-25000), '-250');
    });
  });

  test('any symbol round-trips through parse', () {
    for (final symbol in ['Rs', r'$', '₹', 'AED', '€', 'KSh']) {
      AppRegion.current = resolveRegion(
        const Locale('en', 'PK'),
        symbol: symbol,
      );
      expect(Money.parseMinor(Money.format(485050)), 485050, reason: symbol);
      expect(Money.parseMinor(Money.format(-25000)), -25000, reason: symbol);
    }
  });

  test('format → parse round-trips exactly', () {
    for (final minor in [
      0, 1, 9, 10, 99, 100, 101, 999, 1000, 4850, 485000, 125050,
      99999999, 123456789012, 900719925474099, //
    ]) {
      expect(Money.parseMinor(Money.format(minor)), minor, reason: '$minor');
      expect(Money.parseMinor(Money.format(-minor)), -minor, reason: '-$minor');
    }
  });
}
