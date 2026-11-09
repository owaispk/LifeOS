import 'region.dart';
import 'text.dart';

/// Money is always integer minor units (paisa/cents) — never floats
/// (data model §3, "Money rule").
abstract final class Money {

  /// Parses user/OCR text such as "Rs 4,850", "Rs. 1,250.50", "4850",
  /// or Urdu/Eastern-Arabic digits ("۴۸۵۰") into minor units.
  /// Returns null if no amount can be read. Uses integer maths only.
  static int? parseMinor(String input) {
    final text = normalizeDigits(input);
    final match = RegExp(r'-?\d[\d,]*(?:\.\d{1,2})?').firstMatch(text);
    if (match == null) return null;

    var token = match.group(0)!.replaceAll(',', '');
    // "-250" or "-Rs 250" (sign before the currency symbol).
    final prefix = text.substring(0, match.start).trimLeft();
    final negative = token.startsWith('-') || prefix.startsWith('-');
    if (token.startsWith('-')) token = token.substring(1);

    final parts = token.split('.');
    final major = int.parse(parts[0]);
    final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    final minor = major * 100 + int.parse(fraction);
    return negative ? -minor : minor;
  }

  /// Formats minor units for display with the user's currency symbol
  /// (PBI-035): 485000 → "Rs 4,850", 125050 → "Rs 1,250.50". Whole amounts
  /// drop the ".00". The symbol is display-only; amounts are never converted.
  static String format(int minor) {
    final plain = formatPlain(minor);
    final symbol = AppRegion.current.symbol;
    return plain.startsWith('-')
        ? '-$symbol ${plain.substring(1)}'
        : '$symbol $plain';
  }

  /// Input-field prefix with the user's symbol: "Rs ", "₹ ", "AED ".
  static String get prefix => '${AppRegion.current.symbol} ';

  /// The amount without a symbol, for input fields that show the symbol as
  /// a prefix: 485000 → "4,850".
  static String formatPlain(int minor) {
    final negative = minor < 0;
    final abs = minor.abs();
    final major = abs ~/ 100;
    final fraction = abs % 100;

    final digits = major.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    final decimals = fraction == 0
        ? ''
        : '.${fraction.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}$grouped$decimals';
  }
}
