# PBI-032 — Device Calendar in Today View (read-only)

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 (post-MVP) |
| Story Points | 5 |
| Spec refs | Features §2.2 (appointments, read-only precursor), §10 (dashboard "one morning check") |
| Depends on | PBI-009 (Today view), PBI-021 (Home dashboard) |
| Status | Ready |

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
