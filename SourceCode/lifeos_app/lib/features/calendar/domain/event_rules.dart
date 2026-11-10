// Which events show, and in what order — pure Dart (PBI-032).
import '../../tasks/domain/task_rules.dart' show startOfDay;
import '../platform/calendar_source.dart';

/// All-day events first, then by start time, then by title so the order
/// never jitters between reads.
int byAllDayThenStart(CalEvent a, CalEvent b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final byStart = a.start.compareTo(b.start);
  return byStart != 0 ? byStart : a.title.compareTo(b.title);
}

/// The calendar ids the user has unticked, as stored (comma-separated).
Set<String> parseCalendarsOff(String stored) => {
  for (final id in stored.split(','))
    if (id.trim().isNotEmpty) id.trim(),
};

String storeCalendarsOff(Set<String> ids) =>
    (ids.toList()..sort()).join(',');

/// The calendars to read: everything the phone offers, minus what the
/// user unticked. An unknown (newly added) calendar is included.
List<DeviceCal> visibleCalendars(List<DeviceCal> all, Set<String> off) => [
  for (final c in all)
    if (!off.contains(c.id)) c,
];

/// [events] that fall on [day], in display order. An event that starts
/// earlier but runs across [day] counts as being on it, so a multi-day
/// trip shows on each of its days.
List<CalEvent> eventsOnDay(List<CalEvent> events, DateTime day) {
  final start = startOfDay(day);
  final next = DateTime(start.year, start.month, start.day + 1);
  return [
    for (final e in events)
      if (e.start.isBefore(next) && !_endsBefore(e, start)) e,
  ]..sort(byAllDayThenStart);
}

/// Events grouped by local day for [days] days starting the day after
/// [now] — the same window Upcoming uses for tasks. Days with no events
/// are left out.
Map<DateTime, List<CalEvent>> eventsByDay(
  List<CalEvent> events,
  DateTime now, {
  int days = 7,
}) {
  final from = startOfDay(now).add(const Duration(days: 1));
  final byDay = <DateTime, List<CalEvent>>{};
  for (var i = 0; i < days; i++) {
    final day = DateTime(from.year, from.month, from.day + i);
    final onDay = eventsOnDay(events, day);
    if (onDay.isNotEmpty) byDay[day] = onDay;
  }
  return byDay;
}

/// An all-day event's end is exclusive in some calendar stores and
/// inclusive in others; treating an end at exactly midnight as "the day
/// before" keeps a one-day event off tomorrow.
bool _endsBefore(CalEvent e, DateTime dayStart) {
  if (!e.end.isAfter(e.start)) return e.start.isBefore(dayStart);
  return !e.end.isAfter(dayStart);
}
