// Natural-language quick add (PBI-010) — pure Dart, never throws.
//
// "pay electricity bill Friday 5pm" → title "Pay electricity bill",
// next Friday 17:00, domain money. English plus common Roman-Urdu words.
// "Next week" and "weekend" follow the user's region (PBI-035).
import '../../../core/region.dart';

/// What a parse found. Unset parts are null.
class ParsedTask {
  const ParsedTask({
    required this.title,
    this.date,
    this.hour,
    this.minute = 0,
    this.highPriority = false,
    this.domain,
    this.amount,
    this.matched = const {},
  });

  /// The text with the recognised parts removed (falls back to the input).
  final String title;

  /// The day it's due (no time).
  final DateTime? date;
  final int? hour;
  final int minute;
  final bool highPriority;

  /// money | health | people | vault, when a hint word was found.
  final String? domain;

  /// The amount as written ("Rs 4,520"), when the text carried one.
  final String? amount;

  /// Which pieces were recognised, keyed by [ParsedPart], with the words
  /// they came from (for the preview chips).
  final Map<ParsedPart, String> matched;

  bool get hasTime => hour != null;

  /// The full due date-time: a time without a date means today.
  DateTime? dueAt(DateTime now) {
    final d =
        date ?? (hour != null ? DateTime(now.year, now.month, now.day) : null);
    if (d == null) return null;
    return DateTime(
      d.year,
      d.month,
      d.day,
      hour ?? 0,
      hour == null ? 0 : minute,
    );
  }

  /// The same parse with one part dropped (a tapped-away chip).
  ParsedTask without(ParsedPart part) => ParsedTask(
    title: title,
    date: part == ParsedPart.date ? null : date,
    hour: part == ParsedPart.time ? null : hour,
    minute: part == ParsedPart.time ? 0 : minute,
    highPriority: part == ParsedPart.priority ? false : highPriority,
    domain: part == ParsedPart.domain ? null : domain,
    amount: part == ParsedPart.amount ? null : amount,
    matched: {...matched}..remove(part),
  );
}

enum ParsedPart { date, time, priority, domain, amount }

const _weekdays = {
  // English
  'monday': 1, 'mon': 1, 'tuesday': 2, 'tue': 2, 'tues': 2,
  'wednesday': 3, 'wed': 3, 'thursday': 4, 'thu': 4, 'thurs': 4,
  'friday': 5, 'fri': 5, 'saturday': 6, 'sat': 6, 'sunday': 7, 'sun': 7,
  // Roman Urdu
  'peer': 1, 'pir': 1, 'mangal': 2, 'budh': 3, 'jumerat': 4,
  'jumma': 5, 'juma': 5, 'jummah': 5, 'hafta': 6, 'itwar': 7, 'itwaar': 7,
};

const _months = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

const _partsOfDay = {
  'morning': 9,
  'subah': 9,
  'afternoon': 15,
  'dopahar': 15,
  'evening': 18,
  'shaam': 18,
  'sham': 18,
  'night': 21,
  'tonight': 21,
  'raat': 21,
};

const _domainWords = {
  'money': ['pay', 'bill', 'rent', 'fee', 'fees', 'rs', 'installment', 'bhar'],
  'health': ['doctor', 'medicine', 'dentist', 'clinic', 'pharmacy', 'dawai'],
  'people': ['call', 'meet', 'birthday', 'visit'],
  'vault': ['document', 'passport', 'cnic', 'licence', 'license', 'renew'],
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The next date with day-of-month [dom] on or after [today], clamped to
/// shorter months (31 → 30 Nov).
DateTime _nextDayOfMonth(DateTime today, int dom) {
  for (var k = 0; k < 13; k++) {
    final y = today.year + (today.month - 1 + k) ~/ 12;
    final m = (today.month - 1 + k) % 12 + 1;
    final last = DateTime(y, m + 1, 0).day;
    final d = DateTime(y, m, dom > last ? last : dom);
    if (!d.isBefore(today)) return d;
  }
  return today;
}

/// Parses [input] relative to [now]. Never throws (AC3): anything that
/// goes wrong yields the whole text as the title. Week rules come from
/// [region] (the user's, by default).
ParsedTask parseTask(String input, DateTime now, {RegionFormats? region}) {
  try {
    return _parse(input, now, region ?? AppRegion.current);
  } on Object {
    return ParsedTask(title: input.trim());
  }
}

/// The first day of [today]'s weekend: today's run if it is a weekend day,
/// else the next one. "Next weekend" is the one after that.
DateTime _weekendStart(DateTime today, Set<int> weekend, {bool next = false}) {
  var d = today;
  if (weekend.contains(d.weekday)) {
    // Walk back to the first day of this weekend run (at most 6 steps).
    for (var i = 0; i < 6 && weekend.contains(_addDays(d, -1).weekday); i++) {
      d = _addDays(d, -1);
    }
  } else {
    // Bounded: an empty weekend set must never hang the parser.
    for (var i = 0; i < 7 && !weekend.contains(d.weekday); i++) {
      d = _addDays(d, 1);
    }
  }
  return next ? _addDays(d, 7) : d;
}

ParsedTask _parse(String input, DateTime now, RegionFormats region) {
  final today = _day(now);
  var text = ' ${input.trim()} ';
  final matched = <ParsedPart, String>{};
  DateTime? date;
  int? hour;
  var minute = 0;
  var high = false;

  // Removes [m] (and a leading "on"/"at"/"by"/"ko" glued to it).
  String cut(Match m) {
    final before = text.substring(0, m.start);
    final glue = RegExp(
      r'\b(due\s+(on|by)\s+|due\s+|on|at|by|ko|this)\s*$',
      caseSensitive: false,
    ).firstMatch(before);
    final from = glue?.start ?? m.start;
    final words = text.substring(from, m.end).trim();
    text = '${text.substring(0, from)} ${text.substring(m.end)}';
    return words;
  }

  RegExpMatch? find(String pattern) =>
      RegExp(pattern, caseSensitive: false).firstMatch(text);

  // ── Priority ──
  final pri = find(r'(\s!+(?=\s)|\b(urgent|important|asap|zaroori)\b)');
  if (pri != null) {
    high = true;
    matched[ParsedPart.priority] = cut(pri);
  }

  // ── Amount (PBI-034): "Rs 4,520", "PKR 4520/-", "₨ 900" ──
  String? amount;
  final amt = find(
    r'\b(rs\.?|pkr|inr)\s*([\d][\d,]*)(?:/-)?'
    r'|₨\s*([\d][\d,]*)(?:/-)?',
  );
  if (amt != null) {
    amount = cut(amt);
    matched[ParsedPart.amount] = amount;
  }

  // ── Time ──
  RegExpMatch? m;
  if ((m = find(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b')) != null) {
    var h = int.parse(m!.group(1)!) % 12;
    if (m.group(3)!.toLowerCase() == 'pm') h += 12;
    final min = m.group(2) == null ? 0 : int.parse(m.group(2)!);
    if (h < 24 && min < 60) {
      hour = h;
      minute = min;
      matched[ParsedPart.time] = cut(m);
    }
  } else if ((m = find(r'\b([01]?\d|2[0-3]):([0-5]\d)\b')) != null) {
    hour = int.parse(m!.group(1)!);
    minute = int.parse(m.group(2)!);
    matched[ParsedPart.time] = cut(m);
  } else if ((m = find(r'\b(?:at|baje)\s+(\d{1,2})\b|\b(\d{1,2})\s+baje\b')) !=
      null) {
    var h = int.parse((m!.group(1) ?? m.group(2))!);
    if (h >= 1 && h <= 12) {
      // "at 5": the next 5 o'clock — PM unless that is before 7 (AM-ish
      // hours 7–11 stay AM).
      if (h < 7 || h == 12) h = h == 12 ? 12 : h + 12;
      hour = h;
      matched[ParsedPart.time] = cut(m);
    } else if (h < 24) {
      hour = h;
      matched[ParsedPart.time] = cut(m);
    }
  }
  if (hour == null) {
    final pod = find('\\b(${_partsOfDay.keys.join('|')})\\b');
    if (pod != null) {
      final word = pod.group(1)!.toLowerCase();
      hour = _partsOfDay[word];
      if (word == 'tonight') date = today;
      matched[ParsedPart.time] = cut(pod);
    }
  }

  // ── Date ──
  if ((m = find(r'\b(day after tomorrow|parson)\b')) != null) {
    date = _addDays(today, 2);
    matched[ParsedPart.date] = cut(m!);
  } else if ((m = find(r'\b(today|aaj)\b')) != null) {
    date = today;
    matched[ParsedPart.date] = cut(m!);
  } else if ((m = find(r'\b(tomorrow|tmrw|tmr|kal)\b')) != null) {
    date = _addDays(today, 1);
    matched[ParsedPart.date] = cut(m!);
  } else if ((m = find(r'\bin\s+(\d{1,3})\s+(day|days|week|weeks)\b')) !=
      null) {
    final n = int.parse(m!.group(1)!);
    date = _addDays(today, m.group(2)!.startsWith('week') ? n * 7 : n);
    matched[ParsedPart.date] = cut(m);
  } else if ((m = find(r'\b(next\s+)?(weekend|week-end)\b')) != null) {
    // The user's weekend (Sat–Sun, Fri–Sat, …): its first day.
    date = _weekendStart(today, region.weekend, next: m!.group(1) != null);
    matched[ParsedPart.date] = cut(m);
  } else if ((m = find('\\b(next\\s+)?(${_weekdays.keys.join('|')})\\b')) !=
      null) {
    final wd = _weekdays[m!.group(2)!.toLowerCase()]!;
    var diff = (wd - today.weekday) % 7;
    // "next Friday" = Friday of next week, in the user's weeks (Mon–Sun by
    // default): from Sunday, "next Monday" is tomorrow; from Wednesday,
    // "next Friday" is 9 days away. A bare weekday that is today means
    // today only if a later time fits; otherwise next week.
    if (m.group(1) != null) {
      if (diff == 0) diff = 7;
      final daysLeftThisWeek = 6 - region.positionInWeek(today);
      if (diff <= daysLeftThisWeek) diff += 7;
    } else if (diff == 0 &&
        (hour == null ||
            DateTime(
              today.year,
              today.month,
              today.day,
              hour,
              minute,
            ).isBefore(now))) {
      diff = 7;
    }
    date = _addDays(today, diff);
    matched[ParsedPart.date] = cut(m);
  } else if ((m = find(
        '\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+(${_months.keys.join('|')})\\b'
        '|\\b(${_months.keys.join('|')})\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b',
      )) !=
      null) {
    final day = int.parse((m!.group(1) ?? m.group(4))!);
    final mon = _months[(m.group(2) ?? m.group(3))!.toLowerCase()]!;
    if (day >= 1 && day <= 31) {
      final last = DateTime(today.year, mon + 1, 0).day;
      var d = DateTime(today.year, mon, day > last ? last : day);
      if (d.isBefore(today)) {
        final lastNext = DateTime(today.year + 1, mon + 1, 0).day;
        d = DateTime(today.year + 1, mon, day > lastNext ? lastNext : day);
      }
      date = d;
      matched[ParsedPart.date] = cut(m);
    }
  } else if ((m = find(r'\b(?:on\s+)?(?:the\s+)?(\d{1,2})(st|nd|rd|th)\b')) !=
      null) {
    final dom = int.parse(m!.group(1)!);
    if (dom >= 1 && dom <= 31) {
      date = _nextDayOfMonth(today, dom);
      matched[ParsedPart.date] = cut(m);
    }
  }

  // A time already past today with no date → still today (the user sees
  // it as overdue/now); a date-less "evening" is today.
  if (date == null && hour != null) date = today;

  // ── Domain (hint words stay in the title) ──
  String? domain;
  final lower = ' ${input.toLowerCase()} ';
  for (final e in _domainWords.entries) {
    final hit = e.value.firstWhere(
      (w) => RegExp('\\b$w\\b').hasMatch(lower),
      orElse: () => '',
    );
    if (hit.isNotEmpty) {
      domain = e.key;
      matched[ParsedPart.domain] = hit;
      break;
    }
  }

  // An amount is a money signal in itself ("PKR 4520" carries no hint word).
  if (domain == null && amount != null) domain = 'money';

  var title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  title = title
      .replaceAll(
        RegExp(
          r'^(to|on|at|by)\s+|\s+(on|at|by|ko|due|due\s+(on|by))$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  if (title.isEmpty) title = input.trim();
  if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

  return ParsedTask(
    title: title,
    date: date,
    hour: hour,
    minute: hour == null ? 0 : minute,
    highPriority: high,
    domain: domain,
    amount: amount,
    matched: matched,
  );
}
