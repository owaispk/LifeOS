# PBI-015 — ATC: Fees & Tuition Flow

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.4 |
| Depends on | PBI-013, PBI-004 |
| Status | Ready |

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
