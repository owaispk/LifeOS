# PBI-015 — ATC: Fees & Tuition Flow

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.4 |
| Depends on | PBI-013, PBI-004 |
| Status | Done |

## User Story
As a **parent**, I want school fees for each child reminded automatically, and I want to know when the fee changes.

## Description
- A fee rule is created from setup, or proposed from the first scanned fee voucher: institution, person (child), amount, cycle (monthly / quarterly / semester), due day
- Task title: "Ali — school fee Rs 12,000, due 5th", generated 5 days before the due date
- A scanned voucher with a different amount prompts: "Fee increased from 12,000 → 13,500. Update future tasks?"
- Skip months for vacations. Semester cycles are date-based.
- On completion the receipt is filed under that child's Education folder (through PBI-016)

## Acceptance Criteria
1. A fee rule for child "Ali" generates a task that carries the person chip and the correct title format.
2. A voucher with a new amount shows the update prompt. Accepting it updates the rule and every not-yet-paid future payment.
3. Skip months {6, 7} produce no tasks in June or July.
4. A semester cycle with explicit dates generates only on those dates.

## Grooming Notes (Sprint 5, 2026-11-09)
**Title (AC1):** fee rules with a person produce "Ali - school fee Rs 12,000, due 5th". The rule name is lower-cased after the dash; without a person, the name comes first. The person chip already shows on task tiles.

**When tasks appear:** the generator keeps one next occurrence per rule, with its reminder 5 days before (`remind_days_before = 5`, the fee default). This meets "generated 5 days before" without a second scheduler.

**Voucher scan** (after Save on the confirm step, `fee_voucher` type), matched by institution = `rule.issuer` and student name = person name (case-insensitive) or the chosen person:
- **No matching rule:** a `proposed` fee rule goes into the M1 queue: "Create a fee reminder for Ali - Rs 12,000, due 5th?". The due day comes from the voucher's due date.
- **Rule found, different amount:** dialog "Fee increased from 12,000 -> 13,500. Update future tasks?" (or "decreased"). Yes updates `rule.amount` plus every unpaid payment and its task title. Paid history is never touched.

**Semester dates (AC4)**
- Schema v5 adds `atc_rules.schedule_dates` (JSON list of `YYYY-MM-DD`). When set, occurrences are exactly those dates; skip months still apply.
- The add form shows "Pick dates" when the cycle is "Every 6 months".

**Receipt filing:** paying a fee rule's payment files the receipt in the Education folder with the rule's person (the child), instead of Bills & Receipts.

## Dev & QA Notes (Sprint 5, 2026-11-09)
Code:
- Fee titles in `occurrenceTitle`.
- Schedule dates in `occurrencesFrom` (schema v5 `atc_rules.schedule_dates`).
- "Pick dates" in the add form for 6-monthly cycles.
- Voucher learning plus `applyFeeChange` in `atc_learning.dart`.
- The fee-change dialog on the confirm step.
- Fee receipts are filed in Education by `PaymentService`.
- Form rules in the Fees category are now `kind = fee`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Rule for child Ali → task "Ali — school fee Rs 12,000, due 5th" with Ali's person chip; reminder 30 Nov 09:00 (5 days before 5 Dec). |
| 2 | ✅ | Widget: scanning the fee voucher fixture (Rs 12,000) against a Rs 10,000 rule shows "Fee increased from 10,000 → 12,000. Update future tasks?". "Update" changes the rule, the unpaid payment and the task title. A paid earlier fee keeps Rs 12,000 (service test). The same amount asks nothing. |
| 3 | ✅ | Skip {6, 7} from May → next fees 5 Aug and 5 Sep. The generated payment is 5 Aug. |
| 4 | ✅ | Dates 1 Sep 2026 (past), 15 Feb 2027 and 10 Sep 2027 → only 15 Feb, then 10 Sep after it passes. No monthly ones. Label "On set dates · 1 Sep, 15 Feb, 10 Sep". |

Also: the first voucher for a child proposes "Create a fee reminder for Ali — Rs 12,000, due 5th?" through M1. A fee receipt files in **Education** with the child (service test).

**Change to an older test:** the PBI-016 AC2 test pays a school fee, so its receipt now goes to Education instead of Bills & Receipts. The expectation was updated.

`flutter analyze`: no issues · full suite **370/370 passed** (66 new in Sprint 5), identical on two runs · schema v5 migration tested from v1–v4.
