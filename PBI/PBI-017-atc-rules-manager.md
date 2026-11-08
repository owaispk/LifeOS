# PBI-017 — ATC Rules Manager Screen

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 3 |
| Spec refs | Features §2.6; UI flow §5.1 |
| Depends on | PBI-013 |
| Status | Ready |

## User Story
As a **user**, I want to see and control every automatic rule so I always trust what the app creates.

## Description
- More → ATC Rules: rules grouped by Bills · Fees · Fixed · Appointments
- Row: name, cadence ("~12th monthly"), last/next run, pause toggle
- Detail: edit fields, history ("created 6 tasks, 6 paid on time ✓"), mute/delete
- Header stat: "⚡ ATC created N tasks for you this month"

## Acceptance Criteria
1. Every active, paused and proposed rule is listed in its group.
2. The pause toggle takes effect immediately, and the next generator run skips the rule.
3. Deleting a rule soft-deletes it. Already-created tasks are kept but lose the ⚡ chip.
4. The header count equals the number of ATC tasks created in the current calendar month (tested).
