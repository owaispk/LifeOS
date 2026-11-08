# PBI-019 — Monthly Money Forecast (+ Salary-Aware Mode)

| Field | Value |
|---|---|
| Epic | E4 Money |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §2.5 "Monthly Money Forecast"; UI flow §4.2 |
| Depends on | PBI-013 |
| Status | Ready |

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
