# PBI-030 — Diagnostics Log & Share (test phones)

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 (testing support) |
| Story Points | 3 |
| Spec refs | Features §14 (privacy); data stays on the phone unless the user shares it |
| Depends on | PBI-025 (Settings), PBI-007 (share sheet) |
| Status | Done |

## User Story
As a **tester**, I want the app to keep a log of errors and key events on the phone, so I can send it to the team when something goes wrong.

## Description
- An on-device log, one file per day under the app's private folder, written as JSON lines: time, level (info / warning / error), area, message, and the stack trace for errors.
- **Captured automatically:**
  - uncaught Flutter framework errors and uncaught async/platform errors, with the screen (route) the user was on;
  - errors caught by the app (failed save, OCR failure, notification scheduling failure…).
- **Key events:**
  - app start, with app version, Android version and device model;
  - app resume/pause and screen changes;
  - database upgrades and the file-encryption migration;
  - document saved (type only), OCR finished (type and confidence only);
  - reminders scheduled (count), export and lock events.
- **Privacy first:** never log document titles, OCR text, amounts, names, ID/phone/reference numbers or notes. A scrubber masks digit runs of 4 or more, emails and CNIC/phone patterns in any message as a last line of defence.
- **Retention:** keep 7 days, each day's file capped at 1 MB (older lines dropped first).
- **Settings → Diagnostics:**
  - app and device info, plus the latest entries (newest first), with errors highlighted and an "Errors only" filter;
  - **Share logs:** one ZIP (all log files + `device.txt`) through the OS share sheet;
  - **Clear logs**;
  - **Record a test error**, to check the pipeline.
- **No automatic upload.** Nothing leaves the phone unless the tester taps Share. Automatic crash reporting (Sentry / Crashlytics) was considered and not chosen for now.

## Acceptance Criteria
1. An uncaught Flutter error and an uncaught async error are both written to the log, with level error, the stack trace and the current route.
2. Files older than 7 days are deleted on start; a day's file never grows beyond 1 MB.
3. No personal data is logged: a test feeds titles, CNIC, phone and amount text through the scrubber, and a source scan checks that log calls never pass titles, OCR text, amounts or names.
4. Settings → Diagnostics lists recent entries newest first, with errors highlighted, and the "Errors only" filter works.
5. Share logs produces one ZIP with every log file and `device.txt`; Clear logs leaves no entries.
6. Logging never throws into the app and never blocks the UI. If writing fails, the app carries on.
7. Fully offline; nothing is sent anywhere without the user tapping Share.

## Grooming Notes (2026-11-09)
- **Logger:** `lib/core/log/app_log.dart` holds a global `AppLog` (`AppLog.i/w/e`) so any layer can log without plumbing. Writes go to an in-memory queue that is flushed to the file every 500 ms and on pause, so the UI never waits on disk. Tests use a temporary folder.
- **Capture:** `FlutterError.onError`, `PlatformDispatcher.instance.onError` and `Isolate.current.addErrorListener`, all set up in `main` before `runApp`. The route comes from a GoRouter listener.
- **Device info:** `package_info_plus` (version and build) plus `Platform.operatingSystemVersion`. The device model comes from `device_info_plus` (changed during dev: simpler than a native channel).
- **Scrubber:** masks `\d{4,}` (and spaced or dashed variants such as CNIC 42101-1234567-1 and phone numbers), emails, and "Rs 1,234"-style amounts. It runs on every message and stack trace before writing.
- **Diagnostics screen:** `/more/settings/diagnostics`, reached from Settings → Data → "Diagnostics & logs". All strings are in EN/UR (PBI-025 AC2 still holds).

## Dev & QA Notes (2026-11-09)
Code:
- `lib/core/log/app_log.dart`: the logger, scrubber, retention, read and clear.
- `lib/core/log/diagnostics.dart`: error capture and device facts.
- `lib/features/settings/diagnostics_screen.dart` (`/more/settings/diagnostics`): the screen, the logs ZIP and share.
- Key events logged from `main`, the router (screen changes), capture, OCR, reminder sync, payments, export/delete, lock and DB upgrades.
- The log folder is the app's private `files/logs`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Test: a Flutter framework error and an uncaught async error are both logged at error level, with the stack and the route (`/vault`). Isolate errors are captured too. |
| 2 | ✅ | Test: of 10 daily files, the 7 newest are kept. Writing 1.4 MB in one day stops just under 1 MB. |
| 3 | ✅ | Tests: the scrubber masks CNIC, phone, reference and account numbers, emails and "Rs"/"PKR" amounts, but keeps short counts and versions. A scan of every `AppLog` call in `lib/` finds none passing `.title`, `.ocrText`, `.amountMinor`, `.name`, `.notes`, `.refNumber`, `.issuer`, `.number`, `.value` or `.body`. **Device:** the log holds only versions, the model, counts and screens. |
| 4 | ✅ | Widget: the error is listed above the earlier info line and highlighted; "Errors only" hides info lines. |
| 5 | ✅ | Widget: Share produces a ZIP with `device.txt` and the log; Clear leaves "Nothing logged yet". **Device:** the share sheet shows "LifeOS-logs.zip". |
| 6 | ✅ | Test: the log folder is deleted while running → no exception, the entry is kept in memory. Writes are batched every 500 ms (errors at once) and serialised, so Clear never races a write. |
| 7 | ✅ | No network code. A file leaves the phone only through the user's Share. |

Found in dev:
- The email pattern in the scrubber backtracked quadratically on long text without an "@", stalling the 1 MB test. It now runs only when "@" is present, with bounded lengths.
- Clear could race an in-flight error write that recreated the file; writes are now chained.
- Times showed as "2:17 PM:37"; they're now 24-hour "14:17:37".

`flutter analyze`: no issues · full suite **470/470 passed** · checked on the Android 17 emulator (log file, Diagnostics screen, test error, share sheet).

