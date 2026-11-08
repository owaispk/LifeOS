# PBI-023 — Notification Diet (Digest, Quiet Hours, Toggles)

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §12; Data model `user_settings` |
| Depends on | PBI-012, PBI-020 |
| Status | Ready |

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
