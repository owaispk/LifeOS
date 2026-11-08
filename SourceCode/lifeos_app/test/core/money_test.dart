// PBI-002 AC6: amounts convert to/from minor units with no rounding errors.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/money.dart';

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

    test('other currencies use their symbol', () {
      expect(Money.format(1999, currency: 'USD'), r'$ 19.99');
    });
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
