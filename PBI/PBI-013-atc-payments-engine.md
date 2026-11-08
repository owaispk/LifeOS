# PBI-013 — ATC: Monthly Payments Engine

| Field | Value |
|---|---|
| Epic | E3 Auto Task Creator (ATC) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §2.1, §2.5; Data model `atc_rules`, `payments`, §6.3 |
| Depends on | PBI-009, PBI-012 |
| Status | Done |

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

## Grooming Clarifications (2026-11-08, Sprint 4, before development)
- **Setup:** More → ⚡ Auto Tasks → **Add**: "What do you pay regularly?" chips. Each one maps to a category (schema v4 adds `atc_rules.category_id`):
  - Rent → rent
  - School fee → fees
  - Utility bill → utilities, amount optional ("~"). Pattern learning arrives in PBI-014.
  - Internet / Mobile → internet / mobile
  - Installment / Committee → installment, with a total count
  - Subscription → subscription
  - Custom → name + cycle

  Each rule has a name, amount, due day (1–31), cycle (monthly / quarterly / semester / yearly / once), skip months, a person, and "remind N days before" (default 5).
- **Generator:** pure planning plus a service that applies the plan. It runs at app start and on every app resume.
  - It keeps exactly **one next occurrence** per active rule.
  - When a rule is created, it immediately creates a task and a payment for the next due date on or after today.
  - The following period is generated once that due date has passed, whether paid or not, so an unpaid one stays overdue.
- **Each occurrence:**
  - The task is all-day on the due date, titled e.g. "Rent — Rs 45,000", with `atc_rule_id` set.
  - The payment is `upcoming`, with the rule's category.
  - A reminder fires `remind_days_before` days ahead at 09:00 (PBI-012).
  - Idempotent via `last_generated_period`, the due date of the last generated occurrence.
- **Calendar rules:**
  - Due days clamp to the month's last day (31 → Feb 28/29, Apr 30).
  - Skip months are jumped over.
  - quarterly = +3 months, semester = +6, yearly = +12, once = a single occurrence and then `ended`.
- **Installments:**
  - `installment_done` increments when one is paid (PBI-016). The task title shows "(7 of 24)".
  - Generation stops once `total` occurrences exist, and the rule ends after the last one is paid.
- **Subscriptions:** a yearly "Review <name> subscription?" task, 12 months after the rule is created.
- **Pause / resume:**
  - Paused rules are skipped.
  - Resuming never back-fills: the next occurrence is on or after today.
- **Free tier (stub):** at most 3 active rules. Adding a 4th shows "Free plan includes 3 auto-rules — Premium removes the limit" and creates nothing. `premiumProvider` is `false` until PBI-029.

## Dev & QA Notes (Sprint 4, 2026-11-09)
Code:
- `lib/features/atc/domain/atc_schedule.dart`: pure scheduling.
- `data/atc_service.dart`.
- `ui/rule_form.dart`: the "What do you pay regularly?" sheet.
- Runs at app start and on resume.
- Schema v4 `atc_rules.category_id`, with a tested v1/v2/v3 → v4 migration.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Rent Rs 45,000, day 1, created 8 Nov → exactly one task "Rent — Rs 45,000" + one payment due 1 Dec, category rent, and a reminder 26 Nov 09:00. Service + widget tests. |
| 2 | ✅ | Running the generator repeatedly creates 0 duplicates. Once 1 Dec has passed, exactly one more is created (1 Jan). |
| 3 | ✅ | Skip months {6, 7} → next fee 5 Aug, not June or July. |
| 4 | ✅ | Titles read "(7 of 24)"; generation stops at the total. Paying the last installment sets the rule to `ended`, and Undo reopens it (PBI-016 test). |
| 5 | ✅ | Day 31 → 28 Feb, 29 Feb in leap years, 30 Apr, and back to 31 Mar. |
| 6 | ✅ | The 4th active rule throws `FreeTierLimitException`; the widget test shows "Free plan includes 3 auto-rules — Premium removes the limit." and only 3 rules exist. Premium lifts the limit. |
| 7 | ✅ | Paused → nothing generated. Resumed in March after a December occurrence → next is 1 Apr; Jan–Mar are not back-filled. |

Also: quarterly, semester and yearly cycles counted from the creation month; a yearly subscription review task; one-off rules; unknown amounts shown as "~".

`flutter analyze`: no issues · full suite **304/304 passed** (59 new in Sprint 4), identical on three runs · web build compiles. 25 tests for PBI-013 + PBI-017 (20 unit/service + 5 widget).
