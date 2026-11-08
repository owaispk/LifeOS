# PBI-009 — Tasks: CRUD, Today & Upcoming Views

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §3.1; UI flow §2.1, §2.3, §2.4 |
| Depends on | PBI-002 |
| Status | Ready |

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
