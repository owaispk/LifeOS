# PBI-032 — Device Calendar in Today View (read-only)

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 (post-MVP) |
| Story Points | 5 |
| Spec refs | Features §2.2 (appointments, read-only precursor), §10 (dashboard "one morning check") |
| Depends on | PBI-009 (Today view), PBI-021 (Home dashboard) |
| Status | Done — device QA pending |

## User Story
As a **user**, I want my phone/Google calendar events to appear in LifeOS's Today and Upcoming views, so that my morning check happens in one app instead of two.

## Description
- **Read-only** sync from the device calendar (Android `CalendarContract`, iOS EventKit) via the `device_calendar` plugin. LifeOS never writes, edits or deletes calendar events in this PBI.
- Today view shows the day's events as a distinct row type above tasks: time, title, 📅 marker, calendar colour dot. All-day events pin to the top. Tapping an event opens a small read-only sheet (title, time, location, which calendar).
- Upcoming view interleaves events with tasks on the correct days (next 7 days).
- Home dashboard "Today" summary counts include events ("3 tasks · 2 events").
- **Calendar permission is requested in context** — the first time the user enables the feature, never at app start.
- **Settings → Calendars:** master toggle (default off until the user enables it once), then a checklist of device calendars to include/exclude (e.g. hide "Holidays in Pakistan").
- Events are read fresh on screen open and app resume; nothing is copied into the Drift database (no sync-state to maintain, no stale data). A short in-memory cache avoids re-querying on every rebuild.
- Events do **not** create tasks, reminders or notifications, and do not affect the Life Score (tasks remain the user's own commitments). Appointments OCR → ATC stays V2 as per spec.
- Fully offline: the device calendar store is local; no network involved.
- EN/UR: all new strings localised; event titles render as-is (user content).

## Acceptance Criteria
1. With permission granted and the toggle on, today's device-calendar events appear in the Today view in start-time order above same-time tasks, and all-day events pin to the top.
2. Upcoming shows events on the correct day alongside tasks for the next 7 days.
3. Calendar permission is requested only when the user first enables the feature. If denied, the toggle switches back off with a friendly message and a "Open settings" affordance; the app never crashes and never asks again unprompted.
4. Unchecking a calendar in Settings removes its events everywhere immediately.
5. With the toggle off (the default), no calendar permission is requested and no calendar code touches the platform channel.
6. Events are never stored in the database, never create tasks or notifications, and never change the Life Score (verified by unit tests on the score input and reminder sync).
7. Works offline; a calendar read failure degrades to "tasks only" silently (one log entry, PBI-030), never an error screen.

## Grooming Notes
- Wrap the plugin behind a `CalendarSource` interface (like `ShareInbox` in `capture_platform.dart`) with a fake for widget tests: `Future<List<CalEvent>> eventsBetween(DateTime from, DateTime to)` plus `calendars()` and `requestPermission()`.
- Today/Upcoming already build day-grouped lists (PBI-009); events merge in at the view-model layer, keyed by day.
- Recurring events: the plugin expands instances when queried by range — query by range only, never enumerate recurrence rules by hand.
- Timezones: trust the event's own start/end as returned for the device zone; all-day events are date-only (watch the UTC-midnight trap).
- Settings persistence: the include/exclude set and master toggle in the existing settings store (PBI-025), keyed by calendar id.

## Dev & QA Notes (2026-11-10)

New dependencies: `device_calendar` (read-only use), `app_settings` (the "Open settings" affordance AC3 asks for).

Code, all new under `lib/features/calendar/`:
- `platform/calendar_source.dart`: `CalendarSource` with `DeviceCalendarSource` and an inert `NoCalendar`, the default everywhere until `main()` swaps the real one in on a phone. Only the plugin's read methods are reachable from here — `createOrUpdateEvent` and the delete calls are not wired at all, so "read-only" is structural rather than a promise.
- `domain/event_rules.dart` (pure Dart): which events fall on a day, their order, and which calendars are shown.
- `calendar_providers.dart`: the settings-driven gate, a 2-minute in-memory cache, and `CalendarSettings.enable()` — the one place the permission is ever asked for.
- `ui/event_tile.dart`: the event row and its read-only sheet.

Schema v10 adds `user_settings.calendar_on` (false) and `calendar_calendars_off`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: an all-day "Iqbal Day" and a 15:00 "Standup" both appear under an Events header above the tasks, all-day first (asserted by vertical position, not list order). Unit: all-day pins above timed, then start time, then title. |
| 2 | ✅ | Widget: Upcoming shows "Dentist" (event) and "Pay the gas bill" (task) on the same day. Unit: the window is the 7 days *after* today — today's event and day 8's are both left out. |
| 3 | ✅ | Widget, both ways: refusing leaves `calendar_on` false, shows the message with **Open settings**, and asks exactly once; allowing turns it on, shows the events, and never asks again. |
| 4 | ✅ | Widget: unticking "Holidays in Pakistan" drops its event immediately and keeps the other calendar's. Unit: an unticked id drops out, and a calendar the phone adds *later* is shown without needing a tick — the setting stores exclusions, not inclusions. |
| 5 | ✅ | Widget: with the toggle off (the default), the fake counts **0** calls — no permission check, no read, no prompt. The fake counts every method, so this cannot pass by accident. |
| 6 | ✅ | Widget: with an event showing, the tasks and task_reminders tables are both empty, and the Life Score reads identically before and after the calendar is turned on. Nothing writes events anywhere — there is no table for them. |
| 7 | ✅ | Widget: a calendar store that throws leaves the Tasks screen as tasks-only, with no Events header and no error widget. One `AppLog.w` line; a single unreadable calendar does not lose the others. |

`flutter analyze`: no issues · full suite `flutter test`: **594/594 passed** (16 new).

**Decisions worth knowing:**
- **Events sit in their own block above the tasks**, not interleaved with them. The Description asks for "a distinct row type above tasks"; interleaving would have meant reworking the four Today sections, which AC1 does not ask for.
- **Exclusions, not inclusions**, in the setting: a calendar created on the phone after the user set this up shows by default, instead of silently going missing.
- **All-day times are taken field-by-field**, never zone-converted — the UTC-midnight trap the grooming notes flag. A one-day all-day event is also kept off the following day, since stores disagree on whether its end is inclusive.
- An existing settings test needed `ensureVisible` before tapping **Delete everything**: the new Calendar section made the list long enough that `scrollUntilVisible` left the row just below the fold.

**Not verified:** no device pass. The real permission dialog, actual `CalendarContract` data, recurring-event expansion and the all-day timezone behaviour all need a phone — recurrence and all-day handling are exactly where a real calendar is likely to disagree with a fake. iOS additionally needs a run on a Mac; `NSCalendarsUsageDescription` and `NSCalendarsFullAccessUsageDescription` are in place but untested.

## Follow-up (2026-11-11)
- `device_calendar` 3.9.0 doesn't build for Android with current Flutter: it still uses the removed v1 plugin API (`Registrar`), and its Gradle file calls `jcenter()`. Upgraded to **4.3.3** during PBI-028a device QA, with a `timezone ^0.11.2` dependency override, because 4.3.3 pins `^0.9` and the notifications need 0.11. The calendar code needed no change: event times are now `TZDateTime`, a `DateTime` subclass. Calendar tests pass. Reading a real device calendar on the phone has not been re-checked since the upgrade.
