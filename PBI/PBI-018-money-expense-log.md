# PBI-018 — Money Light: Expense Log & Month Overview

| Field | Value |
|---|---|
| Epic | E4 Money |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §4.1; UI flow §4.1, §4.3, §4.4 |
| Depends on | PBI-002 |
| Status | Done |

## User Story
As a **user**, I want to see where my money went this month without manual bookkeeping.

## Description
- Expenses come from completion-chain entries (automatic) or the quick manual Add Expense sheet (amount, category, date, note, optional receipt)
- Month Overview: total spent this month, a delta arrow vs last month, a donut chart by category, and a recent-expense list with receipt thumbnails
- Expense detail: edit/delete (soft), with a link to the receipt
- All amounts are handled as minor units and formatted per locale ("Rs 12,000")

## Acceptance Criteria
1. A manual expense of Rs 1,250 appears in the list and adds 125000 minor units to the month total.
2. The category totals in the category breakdown add up to the month total (tested).
3. The delta vs last month is computed correctly when last month is 0 (shows "New" and doesn't divide by zero).
4. Month navigation (previous/next) updates every figure.
5. Expenses logged by the completion chain can't lose their payment link when edited.

## Grooming Clarifications (2026-11-08, before development)
- **Chart form: no donut.** The breakdown is a thin segmented bar plus a ranked category list. Each row has a colour swatch, name, amount and share, so you can compare categories directly and read exact figures.
  - Why: per the data-viz guidelines, donuts are hard to compare and we can have up to 9 categories; bars on one line read more accurately.
  - AC2 was reworded from "donut" to "category breakdown".
- **Colours follow the category, not its rank.** Each system category keeps a fixed colour slot (validated palette, light and dark):

  | Category | Rent | Fees & Tuition | Utilities | Internet | Mobile | Installments | Subscriptions |
  |---|---|---|---|---|---|---|---|
  | Colour | blue | orange | aqua | yellow | magenta | green | violet |

  "Other", custom categories and uncategorised spending all share a neutral grey.
- **Month** = local calendar month of `spent_on`. The overview opens on the current month, and the next arrow stops at the current month.
- **Delta vs last month:**
  - Shown as a % with an arrow; up means you spent more.
  - Last month 0 and this month > 0 → "New".
  - Both months 0 → no delta.
  - Never divides by zero.
- **Expense list** = every expense in the selected month, newest first (by `spent_on`, then creation order).
- **Add/Edit Expense sheet:**
  - Fields: amount (> 0, parsed with `Money.parseMinor`), category chips, date (defaults to today; can't be in the future) and note.
  - Edit uses the same sheet and also offers Delete (soft).
- **Payment-linked expenses** (from the completion chain):
  - Editing never changes `payment_id`. The service ignores any attempt.
  - They can't be deleted from Money, because the payment would stay "paid" with no expense. The sheet shows "Logged from a payment" in place of Delete. Undoing a payment happens via PBI-016.
- **Receipts:** attaching a receipt needs the scanner (PBI-003), so it's deferred. Rows that already have a `receipt_document_id` show a 📎 icon.

## Implementation Notes (2026-11-08)
Code: `SourceCode/lifeos_app/lib/features/money/` — `domain/money_rules.dart` (pure), `data/expense_service.dart`, `money_screen.dart`, `ui/` (expense sheet, category breakdown, category colours).

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Add Expense sheet → "Rs 1,250" saved as 125000 and shown in the list and total. Unit + service + widget tests. |
| 2 | ✅ | `summarize()` slices always sum to the month total (incl. uncategorised and unknown categories). Unit test with 9 mixed expenses; widget test checks rows + 90% share. |
| 3 | ✅ | `SpendDelta.compare` — last month 0 → "New", both 0 → hidden, integer-only % (no floats, no divide by zero). Unit tests; widget shows "New · nothing in Oct". |
| 4 | ✅ | Month switcher (◀ ▶, can't pass the current month) recomputes total, delta, breakdown and list. Widget test walks Nov → Oct → Sep → Nov. |
| 5 | ✅ | `ExpenseService.edit` never writes `payment_id`; payment-linked expenses can't be deleted (UI hides Delete, service throws). Service + widget tests. |

Also: the FAB "Expense" action opens the Add Expense sheet; amounts are validated (> 0) with an inline error; the date picker stops at today.

Chart: per the grooming decision, a thin segmented bar + ranked category list instead of a donut. The palette was run through the data-viz validator: light and dark both PASS lightness, chroma, colour-blind and normal-vision separation. Light-mode aqua/yellow/magenta are below 3:1 contrast, so every colour sits next to its name and amount. Rendered in light and dark from a throwaway test and inspected: gaps, rounded ends and entity-fixed colours as intended.

Bug found and fixed: the empty state sat in a fixed-height box and, on phone widths, its "Add expense" button was clipped and untappable. `EmptyState` gained an `inList` mode that sizes to its content.

`flutter analyze`: no issues · `flutter test`: 104/104 passed (22 new); widget tests stable over reruns.

Not verified on a device: the web preview has no database (PBI-002) and there's no Android emulator yet.
