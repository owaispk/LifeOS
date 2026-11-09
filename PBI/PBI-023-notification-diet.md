# PBI-023 — Notification Diet (Digest, Quiet Hours, Toggles)

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §12; Data model `user_settings` |
| Depends on | PBI-012, PBI-020 |
| Status | Done |

## User Story
As a **user**, I want few, useful notifications, not a stream of pings.

## Description
- Morning digest at `digest_time` (default 07:30): one notification, "Life Score 78 ↑3 · 5 tasks · 1 bill due", tap → Home
- Timed items notify individually. Untimed items are batched into the digest.
- Quiet hours (default 22:00–07:00): notifications in the window are deferred to its end (except items the user explicitly timed inside it)
- Per-domain toggles (money, tasks, vault, …)
- At most 1 ATC proposal per day

## Acceptance Criteria
1. With 5 untimed tasks and 1 timed task today, the user gets exactly 2 notifications (digest + timed).
2. A reminder computed for 23:00 with default quiet hours fires at 07:00 instead (tested with the scheduler's pure logic).
3. Turning off the money domain suppresses payment reminders but not the digest.
4. Changing the digest time reschedules it immediately.

## Grooming Notes (Sprint 6, 2026-11-09)
All of this happens in the pure planner, with `ReminderSync` passing the settings in.

**Digest:** one notification at the next `digest_time`, of kind `digest`, with stable id 1.
- Body: "Life Score 78 ↑3 · 5 tasks · 1 bill due". The score is computed for that morning from current data; the counts are tasks due that day plus unpaid payments due that day.
- Tapping it opens Home.
- Rebuilt on every resync, so changing the digest time reschedules it right away (AC4).

**Untimed items:** all-day tasks have no individual reminders (PBI-012), so they appear only in the digest's count (AC1).

**Quiet hours**
- A reminder falling inside quiet hours (which may cross midnight) is moved to the window's end.
- Exception: a task the user timed inside the window (`allDay = false` and its due time in the window) fires as set.

**Domain toggles:** `notif_domains` JSON, e.g. `{"money": false}`.
- Payment reminders follow `money`, expiry reminders follow `vault`, other tasks follow their own domain.
- The digest is never suppressed (AC3).

**ATC proposals:** already at most 1 per day (PBI-014).

## Dev & QA Notes (Sprint 6, 2026-11-09)
Code:
- `reminder_planner.dart`: `NotifyPrefs` (quiet hours, digest time, domain switches), `dietTime`, `digestCounts`, and the `digest` notification kind (id 1, no actions).
- `ReminderSync` builds the localised digest from the Life Score for that morning plus the day's counts, and resyncs on settings, documents and snapshot changes.
- Settings has the digest time, quiet hours and domain chips.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | 5 untimed + 1 timed task today → exactly 2 planned: the digest at 07:30, then the timed one. |
| 2 | ✅ | A reminder at 23:00 → 07:00 the next day. A task the user timed at 23:30 fires at 23:30. Windows inside one day and across midnight are both tested. |
| 3 | ✅ | `{"money": false}` → the payment reminder is dropped; the task reminder and the digest stay. |
| 4 | ✅ | Sync test: changing `digest_time` to 06:45 reschedules the digest within the debounce. |

Also:
- The digest reads "Life Score 100 · 1 task · no bills due" in English, and "صبح بخیر" … in Urdu.
- PBI-012 tests were adjusted to ignore the digest every resync now adds.

`flutter analyze`: no issues · full suite **457/457 passed**, identical on two runs · schema v6 migration tested from v1–v5 · device checks on the Android 17 emulator (2026-11-09).
