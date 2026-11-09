// PBI-035: region formats — phone defaults by country, the user's choices
// over them, and every place that follows the week, date order and symbol.
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/region.dart';
import 'package:lifeos_app/features/home/domain/attention.dart' as home;
import 'package:lifeos_app/features/tasks/domain/nl_parser.dart';
import 'package:lifeos_app/features/tasks/domain/overload.dart' as overload;
import 'package:lifeos_app/features/vault/domain/expiry_ladder.dart';
import 'package:lifeos_app/shared/format.dart';

const sat = DateTime.saturday, sun = DateTime.sunday, mon = DateTime.monday;
const fri = DateTime.friday;

RegionFormats region(String lang, [String? country]) =>
    resolveRegion(Locale(lang, country));

void main() {
  group('phone defaults (AC6)', () {
    test('en-US: \$, Sunday weeks, "Nov 9"', () {
      final r = region('en', 'US');
      expect((r.symbol, r.weekStart, r.dayFirst), (r'$', sun, false));
      expect(r.weekend, {sat, sun});
    });

    test('ur-PK: Rs, Monday weeks, "9 Nov"', () {
      final r = region('ur', 'PK');
      expect((r.symbol, r.weekStart, r.dayFirst), ('Rs', mon, true));
    });

    test('the country decides, not the language', () {
      // `intl` alone would say "$" for an English phone in Pakistan and
      // "E£" for an Arabic phone in Saudi Arabia.
      expect(region('en', 'PK').symbol, 'Rs');
      expect(region('ar', 'SA').symbol, 'SAR');
      expect(region('en', 'AE').symbol, 'AED');
      expect(region('en', 'IN').symbol, '₹');
      expect(region('en', 'GB').symbol, '£');
      expect(region('de', 'DE').symbol, '€');
    });

    test('week starts and weekends follow the country', () {
      expect(region('ar', 'SA').weekStart, sun);
      expect(region('ar', 'SA').weekend, {fri, sat});
      expect(region('ar', 'EG').weekStart, sat);
      expect(region('en', 'AE').weekStart, mon); // UAE: Mon–Fri since 2022
      expect(region('en', 'AE').weekend, {sat, sun});
      expect(region('bn', 'BD').weekend, {fri, sat});
      expect(region('en', 'IN').weekend, {sun});
      expect(region('en', 'GB').weekStart, mon);
    });

    test('no country: the language\'s currency, ISO week, day first', () {
      final r = region('en');
      expect((r.weekStart, r.dayFirst), (mon, true));
      expect(r.symbol, isNotEmpty);
    });
  });

  group("the user's choices win", () {
    test('symbol, week start and date order override the phone', () {
      final r = resolveRegion(
        const Locale('en', 'US'),
        symbol: ' ₦ ',
        weekStart: sat,
        dateOrder: 'dm',
      );
      expect((r.symbol, r.weekStart, r.dayFirst), ('₦', sat, true));
    });

    test('blank or invalid choices fall back to the phone', () {
      final r = resolveRegion(
        const Locale('en', 'US'),
        symbol: '  ',
        weekStart: 3, // Wednesday is not offered
        dateOrder: 'xx',
      );
      expect((r.symbol, r.weekStart, r.dayFirst), (r'$', sun, false));
    });
  });

  group('dates follow the day/month order', () {
    final d = DateTime(2026, 11, 9); // a Monday
    test('day first', () {
      AppRegion.current = resolveRegion(const Locale('en', 'PK'));
      expect(dayMonth(d), '9 Nov');
      expect(formatDay(d), 'Mon, 9 Nov');
    });
    test('month first', () {
      AppRegion.current = resolveRegion(const Locale('en', 'US'));
      expect(dayMonth(d), 'Nov 9');
      expect(formatDay(d), 'Mon, Nov 9');
      expect(formatDay(d, now: DateTime(2025, 1, 1)), 'Mon, Nov 9 2026');
    });
  });

  group('the week starts on the user\'s day', () {
    final wed = DateTime(2026, 11, 11); // Wednesday
    test('Home\'s week', () {
      expect(home.weekOf(wed, weekStart: mon).from, DateTime(2026, 11, 9));
      expect(home.weekOf(wed, weekStart: sun).from, DateTime(2026, 11, 8));
      expect(home.weekOf(wed, weekStart: sat).from, DateTime(2026, 11, 7));
      expect(home.weekOf(wed, weekStart: sat).to, DateTime(2026, 11, 13));
      // On the first day itself, the week starts today.
      expect(
        home.weekOf(DateTime(2026, 11, 7, 15), weekStart: sat).from,
        DateTime(2026, 11, 7),
      );
    });

    test('Overload Shield\'s week', () {
      final days = overload.weekOf(const [], wed, 360, weekStart: sun);
      expect(days.first.day, DateTime(2026, 11, 8));
      expect(days, hasLength(7));
      expect(days.last.day, DateTime(2026, 11, 14));
    });

    test('the weekly expiry nudge is the evening before the week starts', () {
      // From Wednesday 11 Nov: Monday weeks → Sunday 15th, Sunday weeks →
      // Saturday 14th, Saturday weeks → Friday 13th — all at 18:00.
      expect(weeklyNudge(wed, weekStart: mon), DateTime(2026, 11, 15, 18));
      expect(weeklyNudge(wed, weekStart: sun), DateTime(2026, 11, 14, 18));
      expect(weeklyNudge(wed, weekStart: sat), DateTime(2026, 11, 13, 18));
    });
  });

  group('quick add follows the region', () {
    final wed = DateTime(2026, 11, 11, 10); // Wednesday
    RegionFormats r(int start, Set<int> weekend) => RegionFormats(
      symbol: 'Rs',
      weekStart: start,
      weekend: weekend,
      dayFirst: true,
    );

    test('"weekend" is the user\'s weekend', () {
      expect(
        parseTask('clean car weekend', wed, region: r(mon, {sat, sun})).date,
        DateTime(2026, 11, 14), // Saturday
      );
      expect(
        parseTask('clean car weekend', wed, region: r(sun, {fri, sat})).date,
        DateTime(2026, 11, 13), // Friday
      );
      expect(
        parseTask('clean car this weekend', wed, region: r(mon, {sun})).date,
        DateTime(2026, 11, 15), // Sunday only
      );
      final p = parseTask('clean car weekend', wed, region: r(mon, {sat, sun}));
      expect(p.title, 'Clean car');
    });

    test('on a weekend day, "weekend" is today; "next weekend" a week on', () {
      final sunday = DateTime(2026, 11, 15, 10);
      final rs = r(mon, {sat, sun});
      expect(parseTask('rest weekend', sunday, region: rs).date,
          DateTime(2026, 11, 14)); // this weekend began yesterday
      expect(parseTask('rest next weekend', sunday, region: rs).date,
          DateTime(2026, 11, 21));
      expect(parseTask('rest next weekend', wed, region: rs).date,
          DateTime(2026, 11, 21));
    });

    test('"next <day>" means the user\'s next week', () {
      // Saturday 14 Nov. Monday weeks: Sat is still this week, so "next
      // Monday" is the 16th (2 days). Saturday weeks: a new week started
      // today, so "next Monday" is a week later — the 23rd.
      final saturday = DateTime(2026, 11, 14, 10);
      expect(
        parseTask('call next monday', saturday, region: r(mon, {sat, sun}))
            .date,
        DateTime(2026, 11, 16),
      );
      expect(
        parseTask('call next monday', saturday, region: r(sat, {fri})).date,
        DateTime(2026, 11, 23),
      );
    });

    test('an empty weekend never hangs the parser', () {
      final p = parseTask('x weekend', wed, region: r(mon, const {}));
      expect(p.title, isNotEmpty);
    });
  });

  test('AC5: no "Rs" is hard-coded in UI code', () {
    // Parsing input text ("Rs 4,850" on a bill) is fine; displaying it is
    // not — display goes through Money.format / Money.prefix.
    const allowed = {
      'region.dart', // the country table
      'field_extractor.dart', // OCR input normalisation
      'app_log.dart', // the log scrubber recognises amounts
      'nl_parser.dart', // "rs" as a money hint word
      'app_database.dart', // v8 upgrade keeps existing users on what they saw
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final name = f.uri.pathSegments.last;
      if (allowed.contains(name) || name.endsWith('.g.dart')) continue;
      if (name.startsWith('app_localizations')) continue; // generated
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (RegExp(r'''['"]Rs[ .'"]''').hasMatch(code)) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
