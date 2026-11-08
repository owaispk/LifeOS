// Small, dependency-free date labels (English; localised in PBI-025).

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "4:00 PM"
String formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Mon, 9 Nov" (year added when it differs from [now]'s).
String formatDay(DateTime d, {DateTime? now}) {
  final base = '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  return (now != null && d.year != now.year) ? '$base ${d.year}' : base;
}

/// Relative day name: Today / Tomorrow / Yesterday / "Mon, 9 Nov".
String relativeDay(DateTime d, DateTime now) {
  final diff = _day(d).difference(_day(now)).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => formatDay(d, now: now),
  };
}

/// Due label for a task row: "4:00 PM" today, otherwise "Tomorrow",
/// "Yesterday, 4:00 PM", "Mon, 9 Nov".
String dueLabel(DateTime due, {required bool allDay, required DateTime now}) {
  final day = relativeDay(due, now);
  if (allDay) return day;
  if (day == 'Today') return formatTime(due);
  return '$day, ${formatTime(due)}';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026"
String formatMonth(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

/// "Nov" (short month name).
String shortMonth(DateTime d) => _months[d.month - 1];
