import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/log/app_log.dart';
import '../../core/now_provider.dart';
import '../../data/db/app_database.dart';
import '../settings/settings_providers.dart';
import 'domain/event_rules.dart';
import 'platform/calendar_source.dart';

/// The device calendar. Inert until `main()` swaps in the real one, so a
/// test or the web preview never reaches a platform channel.
final calendarSourceProvider = Provider<CalendarSource>(
  (ref) => const NoCalendar(),
);

/// Whether Today and Upcoming should show events at all (PBI-032 AC5).
/// Everything below checks this first: with it off, no calendar code
/// runs and no permission is asked for.
final calendarOnProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider).value?.calendarOn ?? false,
);

/// Calendar ids the user has unticked (AC4).
final calendarsOffProvider = Provider<Set<String>>(
  (ref) => parseCalendarsOff(ref.watch(settingsProvider).value?.calendarsOff ?? ''),
);

/// Every calendar on the phone, for the Settings checklist. Empty while
/// the feature is off.
final deviceCalendarsProvider = FutureProvider<List<DeviceCal>>((ref) async {
  if (!ref.watch(calendarOnProvider)) return const [];
  return ref.watch(calendarSourceProvider).calendars();
});

/// Today's events plus the next 7 days, read fresh and cached in memory
/// for [_cacheFor] so a rebuild does not re-query the platform. Nothing
/// is written to the database (AC6).
const _cacheFor = Duration(minutes: 2);

/// Events for the window Today and Upcoming need. Empty — never an error
/// — when the feature is off, the permission is missing, or the read
/// fails (AC7).
final calendarEventsProvider = FutureProvider<List<CalEvent>>((ref) async {
  if (!ref.watch(calendarOnProvider)) return const [];
  final source = ref.watch(calendarSourceProvider);
  final off = ref.watch(calendarsOffProvider);
  final now = ref.watch(nowProvider)();

  if (!await source.hasPermission()) return const [];
  final cals = visibleCalendars(await source.calendars(), off);
  if (cals.isEmpty) return const [];

  final from = DateTime(now.year, now.month, now.day);
  final to = from.add(const Duration(days: 8));
  try {
    final events = await source.eventsBetween(from, to, calendars: cals);
    // Hold the result briefly: Today, Upcoming and Home all read it.
    // The timer is cancelled with the provider, so a torn-down app (or a
    // widget test) never leaves one pending.
    final link = ref.keepAlive();
    final timer = Timer(_cacheFor, link.close);
    ref.onDispose(timer.cancel);
    return events;
  } on Object catch (e) {
    // AC7: degrade to tasks only, one log line, no error screen.
    AppLog.w('calendar', 'reading events failed: ${e.runtimeType}');
    return const [];
  }
});

/// Today's events, in display order (all-day pinned to the top).
final todayEventsProvider = Provider<List<CalEvent>>((ref) {
  final events = ref.watch(calendarEventsProvider).value ?? const [];
  return eventsOnDay(events, ref.watch(nowProvider)());
});

/// The next 7 days' events, grouped by day, for Upcoming.
final upcomingEventsProvider = Provider<Map<DateTime, List<CalEvent>>>((ref) {
  final events = ref.watch(calendarEventsProvider).value ?? const [];
  return eventsByDay(events, ref.watch(nowProvider)());
});

/// Turning the feature on and off, and the calendar checklist.
class CalendarSettings {
  const CalendarSettings(this._ref);
  final Ref _ref;

  /// Turns events on, asking for the calendar permission in context
  /// (AC3). False when the user said no — the caller switches back off
  /// and says so; nothing is stored, so nothing asks again by itself.
  Future<bool> enable() async {
    final source = _ref.read(calendarSourceProvider);
    final granted =
        await source.hasPermission() || await source.requestPermission();
    AppLog.i('calendar', granted ? 'enabled' : 'permission refused');
    if (!granted) return false;
    await _ref
        .read(settingsServiceProvider)
        .update(const UserSettingsCompanion(calendarOn: Value(true)));
    return true;
  }

  Future<void> disable() => _ref
      .read(settingsServiceProvider)
      .update(const UserSettingsCompanion(calendarOn: Value(false)));

  /// Ticks or unticks one calendar (AC4).
  Future<void> setCalendar(String id, {required bool on}) {
    final off = {..._ref.read(calendarsOffProvider)};
    if (on) {
      off.remove(id);
    } else {
      off.add(id);
    }
    return _ref
        .read(settingsServiceProvider)
        .update(
          UserSettingsCompanion(calendarsOff: Value(storeCalendarsOff(off))),
        );
  }
}

final calendarSettingsProvider = Provider<CalendarSettings>(
  CalendarSettings.new,
);
