// Region formats (PBI-035): currency symbol, first day of the week, weekend
// days and day/month order. Defaults come from the phone's country; every
// one can be overridden in My Profile. Nothing here is inferred from the
// app language — only from the device region or the user's own choice.
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:intl/intl.dart' show NumberFormat;

/// Resolved region formats. Weekdays use [DateTime] numbering (1 = Monday).
class RegionFormats {
  const RegionFormats({
    required this.symbol,
    required this.weekStart,
    required this.weekend,
    required this.dayFirst,
  });

  /// Display currency symbol, e.g. "Rs", "₹", "$", "AED".
  final String symbol;

  /// First day of the week: [DateTime.saturday], sunday or monday.
  final int weekStart;

  /// Weekend days, e.g. {saturday, sunday} or {friday, saturday}.
  final Set<int> weekend;

  /// "9 Nov" (true) or "Nov 9" (false).
  final bool dayFirst;

  /// Days from [weekStart] to [d]'s weekday, 0–6.
  int positionInWeek(DateTime d) => (d.weekday - weekStart) % 7;

  /// Midnight of the first day of [d]'s week.
  DateTime startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - positionInWeek(d));

  @override
  bool operator ==(Object other) =>
      other is RegionFormats &&
      other.symbol == symbol &&
      other.weekStart == weekStart &&
      other.dayFirst == dayFirst &&
      other.weekend.length == weekend.length &&
      other.weekend.containsAll(weekend);

  @override
  int get hashCode =>
      Object.hash(symbol, weekStart, dayFirst, Object.hashAllUnordered(weekend));
}

/// Where pure helpers (money, dates, the quick-add parser) read the
/// region. Kept in step with the settings by the app (like [AppLocale]).
abstract final class AppRegion {
  /// The phone's region. Tests pin it (see `test/flutter_test_config.dart`).
  static Locale deviceLocale = PlatformDispatcher.instance.locale;

  static RegionFormats? _current;

  /// Resolved formats: set from the settings, else the phone's defaults.
  static RegionFormats get current => _current ??= resolveRegion(deviceLocale);
  static set current(RegionFormats value) => _current = value;
}

/// Common pickers in My Profile; the user can also type any symbol.
const commonCurrencySymbols = [
  'Rs', '₹', r'$', '€', '£', 'AED', 'SAR', '৳', '¥', '₦', 'RM',
];

// Country tables. The `intl` package keys its data by language, so on its
// own it reports "$" for an English phone in Pakistan and "E£" for Arabic
// in Saudi Arabia; the country decides these, not the language.
const _symbolByCountry = {
  'PK': 'Rs', 'IN': '₹', 'BD': '৳', 'LK': 'Rs', 'NP': 'Rs',
  'AE': 'AED', 'SA': 'SAR', 'QA': 'QAR', 'KW': 'KWD', 'BH': 'BHD',
  'OM': 'OMR', 'EG': 'E£', 'TR': '₺', 'MY': 'RM', 'ID': 'Rp',
  'NG': '₦', 'KE': 'KSh', 'ZA': 'R', 'JP': '¥', 'CN': '¥', 'GB': '£',
  'US': r'$', 'CA': r'$', 'AU': r'$', 'NZ': r'$', 'SG': r'$',
  'DE': '€', 'FR': '€', 'IT': '€', 'ES': '€', 'NL': '€', 'IE': '€',
  'BE': '€', 'AT': '€', 'PT': '€', 'FI': '€', 'GR': '€',
};

// Sunday-first and Saturday-first countries (CLDR week data); the rest of
// the world starts on Monday (ISO 8601). Pakistan follows its Mon–Fri
// working week here (CLDR lists Sunday), matching LifeOS since the MVP.
const _sundayFirst = {
  'US', 'CA', 'MX', 'BR', 'JP', 'IL', 'PH', 'IN', 'SA', 'KE', 'ZA', 'BD',
  'NP', 'TH', 'KR', 'TW', 'HK', 'SG', 'ID',
};
const _saturdayFirst = {
  'EG', 'IR', 'AF', 'QA', 'KW', 'BH', 'OM', 'JO', 'IQ', 'DZ', 'LY', 'SY',
};

// Friday–Saturday weekends; Iran rests on Friday, India commonly on Sunday.
const _friSatWeekend = {
  'SA', 'QA', 'KW', 'BH', 'OM', 'EG', 'IQ', 'JO', 'DZ', 'LY', 'SY', 'YE',
  'BD',
};

// Month-first dates ("Nov 9").
const _monthFirst = {'US', 'PH', 'PR', 'GU', 'AS'};

/// The phone's defaults, overridden by any explicit choice.
RegionFormats resolveRegion(
  Locale device, {
  String? symbol,
  int? weekStart,
  String? dateOrder,
}) {
  final country = device.countryCode?.toUpperCase();
  final trimmed = symbol?.trim();
  return RegionFormats(
    symbol: (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : _symbolByCountry[country] ?? _languageSymbol(device),
    weekStart: switch (weekStart) {
      DateTime.saturday || DateTime.sunday || DateTime.monday => weekStart!,
      _ =>
        _sundayFirst.contains(country)
            ? DateTime.sunday
            : _saturdayFirst.contains(country)
            ? DateTime.saturday
            : DateTime.monday,
    },
    weekend: _friSatWeekend.contains(country)
        ? const {DateTime.friday, DateTime.saturday}
        : country == 'IR'
        ? const {DateTime.friday}
        : country == 'IN'
        ? const {DateTime.sunday}
        : const {DateTime.saturday, DateTime.sunday},
    dayFirst: switch (dateOrder) {
      'dm' => true,
      'md' => false,
      _ => !_monthFirst.contains(country),
    },
  );
}

/// No (known) country: the language's usual currency, as `intl` knows it.
String _languageSymbol(Locale device) {
  try {
    return NumberFormat.simpleCurrency(
      locale: device.languageCode,
    ).currencySymbol;
  } on Object {
    return r'$';
  }
}
