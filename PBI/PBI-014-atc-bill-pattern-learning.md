# PBI-014 — ATC: Bill Pattern Learning & Proposals

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §2.1, §2.3; UI flow M1; Data model §6.3 pattern detection |
| Depends on | PBI-004, PBI-013 |
| Status | Done (real-scan arrival patterns covered by device QA) |

## User Story
As a **user**, I want the app to learn when my bills arrive and remind me before I even receive them.

## Description
- Each scanned bill records the issuer, billing month, arrival day, due date and amount
- Detection (pure Dart, run after each bill save): group bills by (issuer, ref_number). If there are ≥ 2 consecutive months and the standard deviation of the arrival day is ≤ 4, propose a `bill_pattern` rule with `expected_window = μ ± σ` and `amount_avg`.
- Confidence is a function of cycles observed and regularity. Propose only at ≥ 0.7.
- M1 proposal dialog: "Your electricity bill usually arrives the 10th–14th. Create a monthly reminder?" [Yes, remind me] [No thanks]. At most 1 proposal per day; others queue.
- Predicted task: "Expect electricity bill (~Rs 4,000–6,000)" on the predicted arrival day
- When the real bill is scanned, the predicted task is upgraded with the exact amount and due date, and the reminder ladder is set to the due date
- Spike flag: a new bill more than 2× the rolling average is highlighted "Unusually high bill ⚠"
- Missed month: "No gas bill this month — did you miss it, or should I pause this reminder?"
- The ATC never creates a recurring rule silently

## Acceptance Criteria
1. Two consecutive monthly bills from the same issuer with arrival days 11 and 13 produce a proposal. One bill does not.
2. Arrival days 2 and 20 (irregular) produce no proposal.
3. Declining a proposal sets the rule to dismissed and never proposes it again for that issuer + ref.
4. Two meters (same issuer, different ref_number) are learned as separate rules.
5. Scanning the real bill upgrades the predicted task in place (same task id) with the amount and due date.
6. A bill more than 2× the average shows the ⚠ highlight on the task and the document.
7. Detection, confidence and spike logic have unit tests using fixture bill histories.

## Grooming Notes (Sprint 5, 2026-11-09)
**Data**
- A bill's *arrival day* is the day it was scanned (the document's creation date). Its *billing month* is `period_month`; when OCR found none, the month of the scan is used.
- Schema v5 adds `atc_rules.ref_number`, so two meters from one issuer are separate rules (AC4).
- Rule status gains `dismissed` (AC3). Any live rule for an issuer + ref, in any status, blocks a new proposal.

**Detection** (pure: `lib/features/atc/domain/bill_patterns.dart`)
- Group bills by (issuer, ref) and take the latest run of consecutive billing months.
- Need >= 2 months and population sigma of the arrival days <= 4.
- Window = round(mu - sigma) ... round(mu + sigma), clamped to 1-31.
- Confidence = 0.75 / 0.85 / 0.95 for 2 / 3 / >= 4 cycles, minus 0.03 per day of sigma. Propose at >= 0.7. So 2 bills on the 11th and 13th give 0.72 -> proposed; 2 bills 4 days apart give 0.69 -> wait for a 3rd.

**Proposed rule**
- `kind = bill_pattern`, category Utilities (Internet for PTCL / StormFiber / Nayatel, Mobile for telcos).
- Name from the issuer type, e.g. "Electricity bill (K-Electric)".
- `due_day` = round(mu), the predicted arrival. `amount_avg` = mean of the run. Reminder on the day itself (remind-days 0).

**M1 dialog**
- Shown by the app shell for the oldest `proposed` rule, at most once per calendar day (`app_meta` key). Others wait in the queue.
- "Yes, remind me" -> active (free-tier limit applies). "No thanks" -> dismissed.

**Predicted task:** "Expect electricity bill (~Rs 4,000-6,000)". The range is the min/max of the bills, rounded out to Rs 500.

**Upgrade (AC5)**
- Saving a bill that matches an active bill_pattern rule updates its open predicted task in place: same id, title "Electricity bill - Rs 4,850", due date and source document.
- Its payment gets the amount and due date. Reminders are replaced by the bill ladder (3 days before, on the day, 1 day after).
- If no predicted task is open, a bill task is created for the rule instead.

**Spike (AC6)**
- A bill amount > 2x the average of the previous bills (up to 6) for that issuer + ref is a spike.
- The document gets the tag "⚠ Unusually high bill" (shown as a tag chip). The task title ends with " ⚠" and its notes say "Unusually high bill - Rs X vs usual Rs Y".

**Missed month:** the rule detail screen shows "No gas bill this month - did you miss it, or should I pause this reminder?" with [I'll scan it] [Pause]. It appears when the predicted task is still open more than 3 days after the window ends.

**Not in scope:** proposing from paid receipts (bills only); a daily overdue reminder beyond the ladder's +1 day.

## Dev & QA Notes (Sprint 5, 2026-11-09)
Code:
- `lib/features/atc/domain/bill_patterns.dart`: pure detection, confidence, spike and late-bill checks.
- `data/atc_learning.dart`: runs after Save on the confirm step.
- `ui/proposal_dialog.dart`: the M1 dialog plus the shell listener.
- `AtcService.takeProposalForToday` / `acceptProposal` / `dismissProposal`.
- The rule detail screen shows the missed-month banner.
- Schema v5 adds `atc_rules.ref_number`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Bills arriving on the 11th and 13th → proposed rule (window 11th–13th, confidence 0.72, M1 text "Your electricity bill usually arrives the 11th–13th…"). One bill → nothing. Pure + service tests. |
| 2 | ✅ | Arrival days 2 and 20 → no proposal and no rule. |
| 3 | ✅ | "No thanks" → `dismissed`; a 3rd bill proposes nothing and no task is ever created silently (service + widget). |
| 4 | ✅ | Meters A and B from K-Electric → two rules, due days 12 and 21 (pure + service). |
| 5 | ✅ | After "Yes", the task "Expect electricity bill (~Rs 4,000–6,000)" is due 12 Nov. Scanning the real bill changes the **same task id** to "Electricity bill — Rs 4,850", due 24 Nov, with ladder reminders on 21, 24 and 25 Nov at 09:00. No duplicate task. |
| 6 | ✅ | Rs 12,000 vs a usual Rs 4,500 → the document gets the tag "⚠ Unusually high bill". The task becomes "… Rs 12,000 ⚠" with high priority and the note "Unusually high bill — Rs 12,000 vs usual Rs 4,500". The snackbar reads "Saved to Vault · Unusually high bill ⚠". |
| 7 | ✅ | 13 pure unit tests: consecutive runs incl. across a year end, rescans of one month, confidence table, 2-vs-3 cycles, amount range rounding, spike window of 6, labels, late check. |

Also: the M1 dialog shows at most one proposal per day, and an undecided one is asked again the next day (service + widget). The missed-month banner offers [I'll scan it] [Pause] (widget).

**Dev finding:** an existing PBI-009 test inserted a rule with the default status `proposed`, so the new M1 dialog covered the Tasks screen. The test now uses an active rule.

`flutter analyze`: no issues · full suite **370/370 passed** (66 new in Sprint 5), identical on two runs · schema v5 migration tested from v1–v4.
