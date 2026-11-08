# PBI-019 — Monthly Money Forecast (+ Salary-Aware Mode)

| Field | Value |
|---|---|
| Epic | E4 Money |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.5 "Monthly Money Forecast"; UI flow §4.2 |
| Depends on | PBI-013 |
| Status | Done |

## User Story
As a **user**, I want to know at the start of each month how much my fixed payments will cost and when.

## Description
- Forecast screen: a calendar strip with payment dots, a payment list with status chips (Upcoming / Paid ✓ / Overdue 🔴), and the header "Rs 61,500 total · Rs 23,000 paid · Rs 38,500 remaining"
- Includes active rules even if their payment for the month isn't generated yet (projected)
- Bill-pattern rules use `amount_avg` until the real bill arrives, shown as "~"
- Salary-aware mode: the user sets a salary day and amount. The timeline starts at the salary date, with the insight "41% of income goes to fixed payments".
- A digest card on the 1st of the month: "November fixed payments: Rs 61,500 across 6 items"

## Acceptance Criteria
1. Total = paid + remaining, always (tested).
2. A payment past its due date and unpaid shows Overdue.
3. Projected items (not yet generated) are included once, and never double-counted with generated ones.
4. Salary-aware mode shows the correct percentage, rounded to the nearest whole percent.
5. Forecast computation is a pure function with unit tests.

## Grooming Clarifications (2026-11-08, Sprint 4, before development)
- **Location:** Money tab, with a segmented control: **Overview · Forecast**.
- **Pure function `forecastFor(month, rules, payments, now)`:**
  - **Generated** items: payments with `period_month` in the month. Status:
    - paid
    - overdue (due date passed, unpaid)
    - upcoming
  - **Projected** items: each active rule's occurrences in the month that have no generated payment for that due date yet. They're never double-counted.
  - **Amounts:** generated payments use their own amount. Projected ones use the rule amount, or `amount_avg_minor` shown as "~". Unknown amounts count as 0 and show "amount pending".
  - **Totals:** total = paid + remaining (integers).
- **Screen:**
  - Header "Rs 61,500 total · Rs 23,000 paid · Rs 38,500 remaining".
  - A calendar strip of the month's days, with a dot on each due day; status is shown as text, not colour alone.
  - A list with status chips (Upcoming / Paid ✓ / Overdue 🔴). Overdue and Upcoming items have a **Mark paid** button (PBI-016).
- **Digest card:** at the top, "November fixed payments: Rs 61,500 across 6 items". The notification version is PBI-023.
- **Salary-aware mode** (schema v4 adds `user_settings.salary_day` and `salary_minor`):
  - Set from the Forecast screen.
  - The list starts at the salary day and wraps around the month.
  - Insight: "41% of income goes to fixed payments", total ÷ salary as a whole percent, rounded half-up.

## Dev & QA Notes (Sprint 4, 2026-11-09)
Code: `lib/features/money/domain/forecast.dart` (pure) and `ui/forecast_view.dart`. The Money tab gains **Overview · Forecast**, and the forecast can look up to 12 months ahead. Schema v4 adds `user_settings.salary_day` and `salary_minor`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Total = paid + remaining in every test; the header reads "Rs 12,000 total · Rs 12,000 paid · Rs 0 remaining" after Mark paid (widget). |
| 2 | ✅ | An unpaid payment past its due date is Overdue (🔴 with the word "Overdue"). |
| 3 | ✅ | A rule's not-yet-generated occurrences are projected once, never alongside the generated payment for the same due date. No past projections, paused rules or finished installments. |
| 4 | ✅ | 61,500 of 150,000 → "41% of income goes to fixed payments" (integer half-up). The list starts at salary day and wraps. The widget sets a salary and sees 8%. |
| 5 | ✅ | `forecastFor` is a pure function with 6 unit tests. |

Also: a digest card ("November fixed payments: Rs X across N items"), a calendar strip with due-day dots, and "~" for learned averages.

`flutter analyze`: no issues · full suite **304/304 passed** (59 new in Sprint 4), identical on three runs · web build compiles.
