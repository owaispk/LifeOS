# PBI-012 — Local Reminders & Actionable Notifications

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §12; UI flow §4; Data model §6.5 |
| Depends on | PBI-009 |
| Status | Done |

## User Story
As a **user**, I want reminders that fire on time even without internet, and that I can act on without opening the app.

## Description
- `flutter_local_notifications` scheduling, driven by `task_reminders`
- Reschedule everything on app start, on device reboot, and after timezone changes
- Actionable notifications: payment → [Paid ✓] [Snooze]; expiry → [Set renewal task] [Dismiss]; task → [Done ✓] [Snooze]
- Notification permission is requested in context, when the first reminder is set
- Privacy: when app lock is on, titles are generic ("A payment is due tomorrow")
- Android exact-alarm permission is handled gracefully, with an inexact fallback

## Acceptance Criteria
1. A reminder set 2 minutes ahead fires in airplane mode.
2. Tapping [Paid ✓] marks the payment paid without opening the UI and triggers the completion chain (PBI-016).
3. Snooze reschedules for +1 h (configurable).
4. After a reboot, pending reminders are restored (tested on an Android emulator).
5. Deleting or completing a task cancels its pending notifications.
6. With app lock on, no notification shows an amount, document name or number.

## Grooming Clarifications (2026-11-08, Sprint 2, before development)
- **Architecture:** pure code decides *what* to schedule, and a thin gateway hands that to the phone's notification system (`flutter_local_notifications`).
  - The pure part is fully unit-testable.
  - The gateway is swapped for a fake in tests.
- **Where reminders come from:**
  - A task created with a due *time* gets a default reminder at that time.
  - Task Detail gains a **Reminders** section: add one at the due time, 10 min before, 1 h before, 1 day before, or a custom time; remove one.
  - All-day tasks get no default reminder.
- **Scheduling (rebuild-all, idempotent):** on app start, app resume, timezone change and every reminder or task change, everything is cancelled and the next **60** future reminders are scheduled.
  - 60 because iOS allows only 64 pending notifications.
  - Notification ids are a stable 31-bit hash of the reminder id.
- **Reboot:** the plugin's boot receiver restores alarms, and the next app start rebuilds the schedule as well.
- **Actions:**
  - Payment tasks (ATC tasks with a linked `payments` row): **Paid ✓** · **Snooze**.
  - Tasks: **Done ✓** · **Snooze**.
  - Expiry: **Set renewal task** · **Dismiss**. The handler is built and tested now; PBI-008 generates expiry reminders.
- **What each action does:**
  - **Paid ✓:** completes the task and marks the payment `paid`. The full receipt and expense chain is PBI-016, which will plug in here.
  - **Snooze:** moves that reminder +60 min. The duration is a constant for now; making it a setting is PBI-023.
  - Actions run without opening the app: Android delivers them to a background handler that opens its own database connection.
- **Cancelling:** the planner only schedules reminders on *open* tasks, so completing, skipping or deleting a task drops its notifications at the next rebuild. Reminders are kept, so **Undo** restores them. *(Refined during development: soft-deleting reminders on completion would have broken Undo.)*
- **Privacy:** when `app_lock` is on, titles are generic ("A task is due", "A payment is due") and the body never shows amounts or names.
- **Permissions:**
  - Notification permission is requested the first time a reminder is created.
  - Exact alarms are requested on Android 14+, falling back to inexact scheduling if refused.
- **Device-only ACs:** AC1 (fires in airplane mode) and AC4 (survives reboot) can only be checked on an Android emulator or device. They'll be marked *Pending device QA* until then.

## Dev & QA Notes (Sprint 2, 2026-11-08)
Code: `lib/features/reminders/` — `domain/reminder_planner.dart` (pure plan), `data/reminder_service.dart` (reminders + action handling), `reminder_sync.dart` (rebuild-all on start / writes / resume), `platform/` (gateway interface + `flutter_local_notifications` implementation + background action handler). Tasks: default reminder for timed tasks, reminders follow reschedules and carry over to repeats; Task Detail **Reminders** section. Android manifest (permissions, boot/action receivers) and core-library desugaring added; iOS delegate line added.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ Device QA | Local scheduling via `zonedSchedule` with exact alarms when allowed, else inexact. Needs an Android emulator in airplane mode. |
| 2 | ✅ (chain → PBI-016) | Service test: **Paid ✓** completes the task and marks the payment `paid` with `paid_at`, without UI, and the notification disappears. Receipt → Vault → expense hooks in with PBI-016 as groomed. |
| 3 | ✅ | Service test: **Snooze** moves the reminder to now + 60 min and re-arms it (`snoozeMinutes`, setting in PBI-023). |
| 4 | ✅ Device QA | Boot receiver registered and schedule rebuilt on every start. Needs a reboot on an emulator. |
| 5 | ✅ | Service tests: complete → notification gone, Undo → back, delete → gone. Live sync reacts to writes on its own. |
| 6 | ✅ | Planner + service tests: with app lock on, titles are generic and no name, amount or number appears. Expiry notifications are always generic. |

`flutter analyze`: no issues · full suite `flutter test`: **204/204 passed** (100 new in Sprint 2), identical on two consecutive runs. 24 tests for this PBI (planner, service, sync, widget).

**Not verified:**
- No Android/iOS build has been run, because the Android SDK isn't installed. That leaves unverified:
  - the manifest and Gradle changes
  - the plugin calls
  - the background-isolate action handler
- iOS background actions need extra AppDelegate registration, to be checked on a Mac.

## Device QA (2026-11-09)
Android emulator `sdk gphone64 x86 64`, Android 17 (API 37), Google Play services; debug APK; 2026-11-09.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Timed task "QA reminder offline" (10:16) created → in-context permission prompt → Allow. **Airplane mode on**, app in the background → notification posted at 10:16:47 with **Done ✓ / Snooze**. **Done ✓** completed the task in the background (Today then showed 0 tasks). |
| 4 | ✅ | "QA after reboot" scheduled for 10:50 → `adb reboot` → the alarm was re-registered by 10:46:26 (~40 s after boot) and the notification fired at 10:52:52. |

Notes:
- With exact alarms not granted, Android's inexact window delivered it up to ~3 min late (by design: exact when allowed, else inexact).
- The notification text was correct ("Due 10:16 AM"). The emulator's SystemUI dropped some characters when drawing it; its status-bar clock was garbled the same way. That's an emulator display quirk, not the app.
