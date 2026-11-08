# PBI-017 — ATC Rules Manager Screen

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 3 |
| Spec refs | Features §2.6; UI flow §5.1 |
| Depends on | PBI-013 |
| Status | Done |

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

## Grooming Clarifications (2026-11-08, Sprint 4, before development)
- **Entry:** the More tab becomes a menu with **⚡ Auto Tasks** and **🗑️ Trash** (PBI-007). Other items arrive later.
- **List:**
  - Header: "⚡ ATC created N tasks for you this month". N counts live tasks with an `atc_rule_id` created this calendar month, using the UUIDv7 creation time.
  - Groups:
    - **Bills:** `bill_pattern`, plus fixed rules in the utilities category.
    - **Fees:** `fee`, plus fixed rules in the fees category.
    - **Fixed:** everything else.
    - **Appointments:** `appointment_followup`.
  - Each row: name, cadence ("Monthly · 1st", "~10th–14th monthly"), next run (the next due date), last run, and a pause switch. Proposed rules show "Proposed".
- **Detail:**
  - Edit name, amount, due day, remind-days and skip months.
  - History: "created N tasks · M paid on time", computed from the rule's payments.
  - Pause / Resume, and Delete.
- **Delete:**
  - Soft-deletes the rule.
  - Its tasks are kept but `atc_rule_id` is cleared, so they lose the ⚡ chip.
  - Unpaid generated payments stay in the forecast.

## Dev & QA Notes (Sprint 4, 2026-11-09)
Code:
- More is now a menu: ⚡ Auto Tasks, 🗑️ Trash.
- `lib/features/atc/atc_rules_screen.dart` (route `/more/atc`) and `rule_detail_screen.dart` (`/more/atc/:id`).

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: utility, fee and internet rules appear under Bills, Fees and Fixed. Proposed and ended rules show their status. |
| 2 | ✅ | Widget: the switch pauses immediately (status `paused`); the service test shows the generator skipping it. |
| 3 | ✅ | Delete soft-deletes the rule; its task keeps existing with `atc_rule_id` cleared (no ⚡). The payment stays in the forecast. |
| 4 | ✅ | The header "⚡ ATC created N tasks for you this month" counts ATC tasks by creation month (service + widget tests). |

The detail screen edits name, amount, due day, skip months and remind-days, and shows "Created N tasks · M paid on time" with a ✓ when all were on time.

**QA finding fixed:** a rendered screenshot showed the screen's own "Add" button floating next to the app's ➕. Add now sits in the app bar.

`flutter analyze`: no issues · full suite **304/304 passed** (59 new in Sprint 4), identical on three runs · web build compiles.
