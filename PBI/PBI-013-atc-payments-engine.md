# PBI-013 — ATC: Monthly Payments Engine

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §2.1, §2.5; Data model `atc_rules`, `payments`, §6.3 |
| Depends on | PBI-009, PBI-012 |
| Status | Ready |

## User Story
As a **user**, I want to tell the app once what I pay regularly, and have it create every payment task for me forever.

## Description
- Setup screen "What do you pay regularly?" with a guided checklist: Rent, School fees, Utility bills, Internet/mobile, Installments/Committee (BC), Subscriptions, Custom
- Rule kinds: `fixed` (amount + day), installment (with a total count → "7 of 24 paid"), and subscription (with a yearly-review nudge)
- Cycles: monthly, quarterly, semester, yearly, once. Skip months (e.g. school vacation).
- The **generator** (pure Dart, runs on app start + daily) creates one task + one payment per rule per period, `remind_days_before` ahead of the due date, idempotent via `last_generated_period`
- Generated tasks have `atc_rule_id` set and show "⚡ Created from: <rule>"
- Due days beyond the month's length (e.g. 31st in Feb) clamp to the last day
- The free tier allows at most 3 active rules (premium gate stub)

## Acceptance Criteria
1. Creating a Rent rule (Rs 45,000, day 1) generates exactly one task + payment for the next due period.
2. Running the generator twice for the same period creates 0 duplicates (unit test).
3. Skip months produce no task for those months.
4. An installment rule shows "N of M paid" and ends (`status = ended`) after the last installment.
5. A due day of 31 resolves to Feb 28/29 and Apr 30 (tested).
6. A 4th active rule on the free tier shows the upgrade prompt and isn't created.
7. Pausing a rule stops generation. Resuming does not back-fill missed periods.
