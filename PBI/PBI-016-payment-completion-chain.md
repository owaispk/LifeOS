# PBI-016 — Payment Completion Chain (M2)

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.5 "Completion chain"; UI flow M2 |
| Depends on | PBI-013, PBI-018, PBI-003 |
| Status | Done |

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

## Grooming Clarifications (2026-11-08, Sprint 4, before development)
- **Triggers:**
  - Completing a task that has an unpaid linked payment (tap, swipe, or Task Detail).
  - Forecast **Mark paid**.
  - Notification **Paid ✓** (replacing PBI-012's interim handler).
- **M2 sheet (in-app):** "✓ <title> — Rs X paid". Attach receipt? **Scan** · **Import** · **Skip**. A receipt uses the PBI-003 capture flow to produce a file, then the chain saves it.
- **One transaction:**
  - payment → `paid` + `paid_at`
  - task → done
  - receipt document → Bills & Receipts, the rule's person, title "Receipt — <title>"
  - expense → amount = payment amount, category from the payment or rule, `payment_id` set, `spent_on` = today
  - `receipt_document_id` on both the payment and the expense
  - installment count +1, and the rule ends after the last installment

  If anything fails, everything rolls back, including the receipt files.
- **Idempotent:** paying an already-paid payment returns the existing expense and writes nothing.
- **Undo (5 s snackbar):**
  - The payment goes back to `upcoming`.
  - The expense and the receipt document are soft-deleted (the receipt can be restored from Trash).
  - The task reopens and the installment count is restored.
- **Confirmations:** "Filed in Vault" (only with a receipt) · "Logged in Money". "Score +N" waits for Life Score (PBI-020, Sprint 5).
- **Missing amount:** an unknown payment amount must be entered first; the sheet asks for it.
- **Background:** the notification action runs the same chain with no receipt.

## Dev & QA Notes (Sprint 4, 2026-11-09)
Code:
- `lib/features/money/data/payment_service.dart` (`markPaid` / `undo`).
- `ui/paid_sheet.dart` (M2 sheet, confirmations, Undo).

The chain is used by:
- completing a payment task (tap or swipe)
- Forecast **Mark paid**
- the notification **Paid ✓**, which replaces PBI-012's interim handler

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Skip → exactly one expense (amount, rule category, `payment_id`, today) and no document. The task is done. |
| 2 | ✅ | With a receipt → document "Receipt — School fee" in Bills & Receipts, linked from both the payment and the expense. Widget: "✓ Paid · Filed in Vault · Logged in Money". |
| 3 | ✅ | A forced failure after the receipt was saved rolls back the payment, expense, document and task, and **deletes the receipt files** (none left on disk). |
| 4 | ✅ | Paying twice → `alreadyPaid`, still one expense. |
| 5 | ✅ (score → PBI-020) | Undo restores the payment to `upcoming`, removes the expense, moves the receipt to Trash, reopens the task and restores the installment count. Widget Undo tested. "Score +N" arrives with Life Score in Sprint 5. |

When the amount is unknown, the sheet asks for it before any button works (widget test).

`flutter analyze`: no issues · full suite **304/304 passed** (59 new in Sprint 4), identical on three runs · web build compiles. 12 tests for this PBI (8 service + 4 widget, shared with PBI-019).
