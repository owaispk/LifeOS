# PBI-014 — ATC: Bill Pattern Learning & Proposals

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §2.1, §2.3; UI flow M1; Data model §6.3 pattern detection |
| Depends on | PBI-004, PBI-013 |
| Status | Ready |

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
