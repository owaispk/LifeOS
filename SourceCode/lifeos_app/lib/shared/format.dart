// Small date labels, in the app's language (PBI-025).
import '../core/l10n.dart';

String _weekday(int wd) => switch (wd) {
  1 => l10nNow.wd1,
  2 => l10nNow.wd2,
  3 => l10nNow.wd3,
  4 => l10nNow.wd4,
  5 => l10nNow.wd5,
  6 => l10nNow.wd6,
  _ => l10nNow.wd7,
};

String _mon(int m) => switch (m) {
  1 => l10nNow.mon1,
  2 => l10nNow.mon2,
  3 => l10nNow.mon3,
  4 => l10nNow.mon4,
  5 => l10nNow.mon5,
  6 => l10nNow.mon6,
  7 => l10nNow.mon7,
  8 => l10nNow.mon8,
  9 => l10nNow.mon9,
  10 => l10nNow.mon10,
  11 => l10nNow.mon11,
  _ => l10nNow.mon12,
};

String _month(int m) => switch (m) {
  1 => l10nNow.month1,
  2 => l10nNow.month2,
  3 => l10nNow.month3,
  4 => l10nNow.month4,
  5 => l10nNow.month5,
  6 => l10nNow.month6,
  7 => l10nNow.month7,
  8 => l10nNow.month8,
  9 => l10nNow.month9,
  10 => l10nNow.month10,
  11 => l10nNow.month11,
  _ => l10nNow.month12,
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "4:00 PM"
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Mon, 9 Nov" (year added when it differs from [now]'s).
String formatDay(DateTime d, {DateTime? now}) {
  final base = '${_weekday(d.weekday)}, ${d.day} ${_mon(d.month)}';
  return (now != null && d.year != now.year) ? '$base ${d.year}' : base;
}

/// Relative day name: Today / Tomorrow / Yesterday / "Mon, 9 Nov".
String relativeDay(DateTime d, DateTime now) {
  final diff = _day(d).difference(_day(now)).inDays;
  return switch (diff) {
    0 => l10nNow.today,
    1 => l10nNow.tomorrow,
    -1 => l10nNow.yesterday,
    _ => formatDay(d, now: now),
  };
}

/// Due label for a task row: "4:00 PM" today, otherwise "Tomorrow",
/// "Yesterday, 4:00 PM", "Mon, 9 Nov".
String dueLabel(DateTime due, {required bool allDay, required DateTime now}) {
  final day = relativeDay(due, now);
  if (allDay) return day;
  if (_day(due) == _day(now)) return formatTime(due);
  return '$day, ${formatTime(due)}';
}

/// "November 2026"
String formatMonth(DateTime d) => '${_month(d.month)} ${d.year}';

/// "Nov" (short month name).
String shortMonth(DateTime d) => _mon(d.month);
