// The device calendar, behind an interface (PBI-032) so Today, Upcoming
// and Home are testable without a real calendar store.
//
// Read-only on purpose: LifeOS never creates, edits or deletes an event.
// The plugin's write methods are not reachable from here.
import 'package:device_calendar/device_calendar.dart' as dc;

import '../../../core/log/app_log.dart';

/// One calendar the phone offers (Personal, Work, Holidays …).
class DeviceCal {
  const DeviceCal({
    required this.id,
    required this.name,
    this.colorValue,
    this.account = '',
  });

  final String id;
  final String name;

  /// ARGB, as the platform reports it; null when it has no colour.
  final int? colorValue;

  /// The account it belongs to, shown under the name to tell two
  /// "Personal" calendars apart.
  final String account;
}

/// One event, as read. Times are local; an all-day event is date-only.
class CalEvent {
  const CalEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.location = '',
    this.calendarName = '',
    this.colorValue,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String location;
  final String calendarName;
  final int? colorValue;

  /// The local day it belongs to.
  DateTime get day => DateTime(start.year, start.month, start.day);

  CalEvent withCalendar(DeviceCal cal) => CalEvent(
    id: id,
    calendarId: calendarId,
    title: title,
    start: start,
    end: end,
    allDay: allDay,
    location: location,
    calendarName: cal.name,
    colorValue: cal.colorValue,
  );
}

abstract interface class CalendarSource {
  /// Whether the calendar permission is already granted. Never prompts.
  Future<bool> hasPermission();

  /// Asks for the permission, in context — only ever called when the user
  /// turns the feature on (AC3).
  Future<bool> requestPermission();

  /// The calendars on this device. Empty when the permission is missing.
  Future<List<DeviceCal>> calendars();

  /// Events starting in [from]..[to], from [calendars] only. Recurring
  /// events come back as expanded instances because the query is by
  /// range — recurrence rules are never walked by hand.
  Future<List<CalEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    required List<DeviceCal> calendars,
  });
}

/// The real device calendar.
class DeviceCalendarSource implements CalendarSource {
  DeviceCalendarSource();

  final _plugin = dc.DeviceCalendarPlugin();

  @override
  Future<bool> hasPermission() async =>
      (await _plugin.hasPermissions()).data ?? false;

  @override
  Future<bool> requestPermission() async =>
      (await _plugin.requestPermissions()).data ?? false;

  @override
  Future<List<DeviceCal>> calendars() async {
    try {
      final result = await _plugin.retrieveCalendars();
      return [
        for (final c in result.data ?? const <dc.Calendar>[])
          if (c.id != null)
            DeviceCal(
              id: c.id!,
              name: (c.name ?? '').trim(),
              colorValue: c.color,
              account: (c.accountName ?? '').trim(),
            ),
      ];
    } on Object catch (e) {
      // AC7: a calendar that cannot be read degrades to tasks only.
      AppLog.w('calendar', 'retrieveCalendars failed: ${e.runtimeType}');
      return const [];
    }
  }

  @override
  Future<List<CalEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    required List<DeviceCal> calendars,
  }) async {
    final events = <CalEvent>[];
    for (final cal in calendars) {
      try {
        final result = await _plugin.retrieveEvents(
          cal.id,
          dc.RetrieveEventsParams(startDate: from, endDate: to),
        );
        for (final e in result.data ?? const <dc.Event>[]) {
          final event = _toCalEvent(e, cal);
          if (event != null) events.add(event);
        }
      } on Object catch (err) {
        // One unreadable calendar must not lose the others (AC7).
        AppLog.w('calendar', 'retrieveEvents failed: ${err.runtimeType}');
      }
    }
    return events;
  }

  static CalEvent? _toCalEvent(dc.Event e, DeviceCal cal) {
    final start = e.start;
    if (e.eventId == null || start == null) return null;
    final allDay = e.allDay ?? false;
    // All-day events arrive at midnight in some zone; taking the calendar
    // fields as they come keeps the day the user sees, instead of letting
    // a UTC conversion drag it onto the day before.
    final s = allDay
        ? DateTime(start.year, start.month, start.day)
        : start.toLocal();
    final rawEnd = e.end ?? start;
    final end = allDay
        ? DateTime(rawEnd.year, rawEnd.month, rawEnd.day)
        : rawEnd.toLocal();
    return CalEvent(
      id: e.eventId!,
      calendarId: cal.id,
      title: (e.title ?? '').trim(),
      start: s,
      end: end.isBefore(s) ? s : end,
      allDay: allDay,
      location: (e.location ?? '').trim(),
      calendarName: cal.name,
      colorValue: cal.colorValue,
    );
  }
}

/// No calendar: the default everywhere until `main()` wires the real one,
/// and in tests. Nothing here touches a platform channel.
class NoCalendar implements CalendarSource {
  const NoCalendar();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<DeviceCal>> calendars() async => const [];

  @override
  Future<List<CalEvent>> eventsBetween(
    DateTime from,
    DateTime to, {
    required List<DeviceCal> calendars,
  }) async => const [];
}
