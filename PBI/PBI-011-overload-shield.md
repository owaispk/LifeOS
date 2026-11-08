# PBI-011 — Overload Shield

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §3.2; UI flow §2.5 |
| Depends on | PBI-009 |
| Status | Done |

## User Story
As a **user**, I want the app to stop me from overloading a day so my plans are realistic.

## Description
- Day capacity comes from the user's working window (default 6 h, set in Settings)
- Day load = the sum of `duration_min` for open tasks due that day
- When saving a task makes a day exceed 100% of capacity, show a soft-block dialog: "Monday is already full (6.5h of 6h)", a mini week bar chart, and the buttons **Move to <suggested day>** · Pick a day · Add anyway
- Suggested day = the nearest future day under 70% load
- ATC payment tasks count toward load but are **never** blocked
- Weekly heatmap in the Upcoming view

## Acceptance Criteria
1. Adding a 60-minute task to a day with 5.5 h of 6 h load shows the dialog. Adding it to a day with 4 h does not.
2. The suggested day is the nearest day under 70%. The capacity calculator has unit tests.
3. "Add anyway" saves without changes. "Move" saves on the suggested day.
4. ATC-generated payment tasks never trigger the dialog.
5. The heatmap shows 7 days with load percentages. Days over 100% are highlighted.

## Grooming Clarifications (2026-11-08, Sprint 2, before development)
- **Capacity:**
  - Stored per user as `user_settings.day_capacity_min` (default 360 = 6 h; schema v2).
  - The Settings screen that edits it is PBI-025. Until then the default applies.
- **Day load:** the sum of `duration_min` for open tasks due that local day, all-day and timed alike. Undated tasks don't count.
- **When it checks:**
  - Creating a task with a due date.
  - Changing a task's date in Task Detail.
  - Snooze doesn't check, because it's a deliberate quick action.
- **Trigger:** a day's load *including the new task* goes over 100% of capacity.
- **Suggested day:** the nearest day after the chosen day, at most 14 days ahead, that meets both conditions:
  - its current load is under 70%
  - adding the task keeps it at or under 100%

  If no day qualifies, only **Pick a day** and **Add anyway** are offered.
- **ATC exemption:** tasks with `atc_rule_id` count toward load but never trigger the dialog (bills don't negotiate).
- **Dialog:**
  - Title: "Monday is already full (6.5h of 6h)".
  - A mini bar chart of the chosen day's week, one bar per day, with a 100% marker.
  - Buttons: **Move to <day> (suggested)** · **Pick a day** · **Add anyway**.
- **Heatmap:**
  - Shown at the top of Upcoming: 7 day cells (today through +6), each showing its load %.
  - Colouring is single-hue sequential (deeper = fuller).
  - Days over 100% get a ⚠ icon and the word "Full", never colour alone.

## Dev & QA Notes (Sprint 2, 2026-11-08)
Code: `lib/features/tasks/domain/overload.dart` (pure), `ui/overload_dialog.dart` (dialog, week chart, heatmap), `ui/task_actions.dart` (`confirmCapacity`), wired into New Task and Task Detail. Schema v2 adds `user_settings.day_capacity_min` (migration tested).

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Unit: 60 min onto 5.5 h → overloaded; onto 4 h → no dialog; exactly 100% fits. Widget: New Task → Tomorrow + 1 h on a 5.5 h day shows "Monday is already full (6.5h of 6h)"; a 4 h day saves silently. |
| 2 | ✅ | `suggestDay` unit tests: skips days ≥ 70% and days the task would overflow; 14-day horizon (no suggestion → only Pick / Add anyway); past days suggest from today. |
| 3 | ✅ | Widget: **Add anyway** saves on Monday; **Move to Tue** saves on Tuesday with the same duration; dismissing returns to the sheet without saving. |
| 4 | ✅ | Unit: ATC tasks never trigger the dialog but still count toward the day load. Detail rescheduling passes `isAtc`. |
| 5 | ✅ | Widget: Upcoming shows 7 cells (today…+6) with load %; a 117% day shows "⚠ Full" with a red outline (not colour alone). |

`flutter analyze`: no issues · full suite `flutter test`: **204/204 passed** (100 new in Sprint 2), identical on two consecutive runs. 21 tests for this PBI (16 unit + 5 widget).

QA findings fixed:
- The dialog's week chart overflowed (fixed height). It now sizes to its content.
- Heatmap cells grew to unequal heights when labels wrapped. They're now equal height.

Both were found in tests and in rendered screenshots.
Not verified on a device (no Android SDK yet).
