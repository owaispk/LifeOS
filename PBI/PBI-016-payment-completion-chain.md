# PBI-016 — Payment Completion Chain (M2)

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.5 "Completion chain"; UI flow M2 |
| Depends on | PBI-013, PBI-018, PBI-003 |
| Status | Ready |

## User Story
As a **user**, I want one action to mark a bill paid, file the receipt, log the expense and update my score.

## Description
- Checking off a payment task (in-app or from a notification) opens the M2 bottom sheet: "✓ School fee — Rs 12,000 paid" · 📎 Attach receipt? [Scan] [Gallery] [Skip]
- One transaction then: payment `status = paid` and `paid_at` → the receipt document is created in the right folder/person → an expense is created with the rule's category → the Life Score is recomputed
- Three stacked micro-confirmations animate in: "Filed in Vault · Logged in Money · Score +N"

## Acceptance Criteria
1. Marking paid with Skip creates exactly one expense (amount = payment amount, category from the rule) and no document.
2. Marking paid with a receipt also creates the document, linked through `receipt_document_id` on both the payment and the expense.
3. All writes happen in one DB transaction. A failure rolls back everything (tested).
4. Paying a payment twice (e.g. double tap) creates no second expense.
5. Undoing a paid payment within 5 s reverses the payment, expense and score change.
