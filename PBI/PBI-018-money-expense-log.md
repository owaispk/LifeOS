# PBI-018 — Money Light: Expense Log & Month Overview

| Field | Value |
|---|---|
| Epic | E4 Money |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §4.1; UI flow §4.1, §4.3, §4.4 |
| Depends on | PBI-002 |
| Status | Ready |

## User Story
As a **user**, I want to see where my money went this month without manual bookkeeping.

## Description
- Expenses come from completion-chain entries (automatic) or the quick manual Add Expense sheet (amount, category, date, note, optional receipt)
- Month Overview: total spent this month, a delta arrow vs last month, a donut chart by category, and a recent-expense list with receipt thumbnails
- Expense detail: edit/delete (soft), with a link to the receipt
- All amounts are handled as minor units and formatted per locale ("Rs 12,000")

## Acceptance Criteria
1. A manual expense of Rs 1,250 appears in the list and adds 125000 minor units to the month total.
2. The category totals in the donut add up to the month total (tested).
3. The delta vs last month is computed correctly when last month is 0 (shows "New" and doesn't divide by zero).
4. Month navigation (previous/next) updates every figure.
5. Expenses logged by the completion chain can't lose their payment link when edited.
