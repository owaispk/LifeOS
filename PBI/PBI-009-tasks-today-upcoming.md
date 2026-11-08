# PBI-009 — Tasks: CRUD, Today & Upcoming Views

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §3.1; UI flow §2.1, §2.3, §2.4 |
| Depends on | PBI-002 |
| Status | Done |

## User Story
As a **user**, I want to capture tasks quickly and see exactly what matters today.

## Description
- Task properties: title, notes, due date/time, all-day flag, reminders, priority (low/med/high), domain, person, repeat (RRULE), sub-tasks, Vault attachments, duration estimate (default 30 min)
- New Task bottom sheet: a single text field, with the full form under "More options"
- Task Detail: inline edit, sub-task checklist, attachments strip, an ATC source line (when present), and Delete / Skip this cycle / Mute rule
- Tasks tab segments: **Today · Upcoming (7 days) · Domains**
- Today ordering: **Overdue** → **Timed** (chronological) → **Payments ⚡** (by due date) → **Anytime** (by priority)
- Swipe right = complete (haptic + tick animation). Swipe left = snooze (tonight / tomorrow / pick).
- Repeating tasks create the next occurrence when completed

## Acceptance Criteria
1. A task can be created with only a title and appears in Today under Anytime.
2. The Today ordering matches the spec exactly (covered by a sorting unit test with mixed fixtures).
3. Completing a task sets `status = done` and `completed_at`, and removes it from Today. Undo is available for 5 s.
4. Completing a repeating task creates exactly one next occurrence per the RRULE (daily / weekly / monthly tested).
5. Snooze "tomorrow" moves `due_at` to 09:00 local next day.
6. Upcoming groups tasks by day for the next 7 days. Empty days are hidden.
7. ATC tasks show the ⚡ chip. Their source line opens the source document.
8. Every list has an illustrated empty state with an "Add task" action.

## Grooming Clarifications (2026-11-08, before development)
- **Today** = open tasks that are undated, due today, or overdue. "Today" uses the phone's local time.
- **Sections:** a task is *Overdue* if it's timed and its time has passed, or all-day and due before today. Open ATC tasks (`atc_rule_id` set) go in *Payments ⚡*. Remaining timed tasks go in *Timed*. Everything else goes in *Anytime* (high → low priority, then oldest first).
- **Upcoming** = the 7 days after today (tomorrow … today+7). Today itself is in the Today view.
- **Domains** = all open tasks grouped by domain, soonest due first.
- **All-day due dates** are stored as local midnight (epoch-ms).
- **Repeat** supports `FREQ=DAILY|WEEKLY|MONTHLY` with `INTERVAL` (and `BYMONTHDAY` for monthly, so the 31st clamps to month end without drifting). On completion exactly one next occurrence is created from the due date. If that date is already past, it rolls forward to the first occurrence on or after today, so missed cycles don't pile up. Subtasks are copied, unchecked.
- **Undo** (5 s) reopens the task and removes the next occurrence it created.
- **Snooze:** *Tonight* = today 20:00 (or now + 1 h if it's already past 20:00). *Tomorrow* = 09:00 next day. *Pick* = date and time pickers. A snoozed task becomes timed.
- **Out of this PBI:**
  - Vault attachments: they need a Vault (PBI-005) plus a task↔document link table the data model doesn't have yet.
  - Reminders: PBI-010/012.
  - Voice and natural-language input: PBI-010.
- **Source line:** until the Document Viewer exists (PBI-007), it opens a document summary sheet (title, type, issuer).

## Implementation Notes (2026-11-08)
Code: `SourceCode/lifeos_app/lib/features/tasks/` — `domain/task_rules.dart` (pure rules), `data/task_service.dart` (use-cases), `tasks_screen.dart`, `ui/` (tile, new-task sheet, detail, actions).

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Title-only create → Anytime. `task_service_test` + widget test "AC1" (types a title in the sheet, sees it under ANYTIME). |
| 2 | ✅ | `todaySections()` — unit test with 13 mixed tasks checks section order and in-section sorting; widget test checks headers render in order. |
| 3 | ✅ | `complete()` sets `done` + `completed_at`; tap or swipe-right completes; 5 s Undo snackbar reopens. Widget tests for tap + Undo and for swipe. |
| 4 | ✅ | `RepeatRule` (daily/weekly/monthly, interval, BYMONTHDAY clamp, leap years, roll-forward). Exactly one next occurrence, subtasks copied unchecked; Undo removes it. Unit + service + widget tests. |
| 5 | ✅ | Snooze → Tomorrow = 09:00 next day (also Tonight / Pick). Unit test + widget test (swipe left → Tomorrow → appears in Upcoming). |
| 6 | ✅ | `upcomingByDay()` — next 7 days, empty days hidden. Unit test + widget test (tasks on +1 and +3 → only two day headers). |
| 7 | ✅ | ⚡ chip on ATC tasks; detail source line "Created from: <document>" opens a document summary sheet (stand-in for PBI-007). Widget test. |
| 8 | ✅ | Today, Upcoming and Domains each show an empty state with "➕ Add task". Widget test. |

Also built: Task Detail (inline title/notes, due date + time, priority, life area, person, repeat, sub-tasks, Delete with confirm, Skip this cycle / Mute this rule for ATC tasks); the FAB "Task" action now opens the New Task sheet.

`flutter analyze`: no issues · `flutter test`: 82/82 passed (31 new), widget tests stable over 3 reruns.

Notes:
- Web preview: the Tasks tab shows "Tasks aren't available" because the web build has no database yet (see PBI-002). Visual check happens on Android.
- Test harness: the test database is opened in the real async zone, so widget tests call `settle()` after UI-triggered writes (documented in `test/widget_test_utils.dart`). This is a test-only concern.
- Deferred as groomed: Vault attachments (needs PBI-005 + a task↔document link table), reminders (PBI-010/012), voice/NL input (PBI-010).
