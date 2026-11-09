# PBI-021 — Home Dashboard

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §10; UI flow §1, §1.2 |
| Depends on | PBI-020, PBI-009, PBI-008, PBI-019 |
| Status | Done |

## User Story
As a **user**, I want to open the app and see, on one screen, what needs me today.

## Description
Top to bottom:
1. Greeting ("Salam, <name> 👋"), notification centre, profile
2. Life Score ring (animates 0 → value over 600 ms) + delta vs yesterday + "N things need attention" → Score detail
3. **Needs attention:** overdue payments and expiring documents, max 3 + "See all". Swipe right = done/paid.
4. **Today's tasks** (⚡ marks ATC items)
5. **Money strip:** "Rs 14,500 in payments this week" → Money
6. Quick actions via the FAB

Rules: max 1 screen of content before scrolling, zero ads ever, pull-to-refresh recomputes the score, and friendly prompts instead of blank areas for new users.

## Acceptance Criteria
1. Needs Attention shows at most 3 items, ordered by urgency. "See all" opens the full list.
2. Swiping a payment right runs the completion chain (PBI-016).
3. The week money strip equals the sum of unpaid payments due Monday–Sunday of the current week.
4. A new user sees empty-state prompts ("Scan your first document 📸"), not empty sections.
5. Pull-to-refresh updates the score and delta.
6. A widget test verifies section order and the 3-item cap.

## Grooming Notes (Sprint 5, 2026-11-09)
**Greeting:** "Salam, <name> 👋" uses the `self` person's name, or just "Salam 👋" while it is still the default "Me". The bell opens Needs Attention, and the profile icon opens More.

**Score card:** ring animating 0 -> value in 600 ms, plus up/down delta vs yesterday. Below it, "N things need attention" or "All clear today ✓". Tapping opens `/home/score`.

**Needs Attention items** (pure `attention.dart`)
- Payments not paid or skipped that are due on or before tomorrow (overdue included).
- Documents expiring within 30 days, or already expired.
- Ordered by days until the deadline (overdue first); on a tie, payments come before documents.
- Shows at most 3, then "See all (N)" -> `/home/attention`.
- Swiping a payment right runs `payWithChain`. Tapping a document opens it.

**Today's tasks:** today's tasks in the Tasks tab order, up to 5 + "See all" -> Tasks. ⚡ marks ATC items through the existing task tile.

**Money strip:** "Rs X in payments this week" = sum of unpaid payments due Monday-Sunday of this week, with unknown amounts excluded. Tapping it opens Money.

**New user:** with no tasks, documents or rules, the sections become prompts: "Scan your first document 📸", "Add what you pay regularly ⚡", "Add a task ➕". Each existing section shows a friendly line instead of being empty.

**Pull-to-refresh:** recomputes the score, writes the snapshot and updates the delta. The ring, attention count and delta are otherwise live: they follow the data streams.

**Proposals:** the app shell (not just Home) shows the M1 ATC proposal dialog from PBI-014/015, so it appears on whichever tab the user is on.

## Dev & QA Notes (Sprint 5, 2026-11-09)
Code:
- `lib/features/home/home_screen.dart`.
- `domain/attention.dart` (pure).
- `ui/attention_tile.dart`.
- `attention_screen.dart` (`/home/attention`).

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Ordering: overdue payment (−3 days) → payment due tomorrow → document expiring tomorrow → document in 30 days. Payments with 2+ days left and documents with 31+ days stay out (pure). Widget: Home shows Rent, Electricity, Visa and "See all (4)"; See all lists all 4. |
| 2 | ✅ | Widget: swiping the payment right opens the M2 sheet → Skip → payment paid, Rs 4,850 expense logged, row gone. |
| 3 | ✅ | Mon 2 – Sun 8 Nov: Rs 10,000 + Rs 4,500 = "Rs 14,500 in payments this week". Unknown, paid, last-week and next-week payments are excluded (pure + widget). |
| 4 | ✅ | A new user sees "Scan your first document 📸", "Add what you pay regularly ⚡" and "Add a task ➕", and no empty sections. |
| 5 | ✅ | Pull-to-refresh → 88, ↓12, and today's snapshot written. |
| 6 | ✅ | Widget: the order is score → attention → today → money (measured positions), and attention is capped at 3. |

Also:
- Greeting "Salam, Owais 👋", or "Salam 👋" while the name is still "Me".
- The bell shows a badge and opens the full list; the profile icon opens More.
- The ring animates 0 → score in 600 ms.
- Friendly lines ("Nothing urgent — nice ✓", "A clear day.") instead of empty sections.
- Rendered screenshots reviewed: new user, filled Home, Score detail, M1 dialog.

**Test harness change:** Home now watches most tables from the first frame. A test helper that ran several writes outside the widget test's zone could therefore deadlock. `TestApp.write` now runs writes the way taps do. The PBI-001 shell tests expect the greeting as Home's title.

**Note for review:** on a Sunday the money strip shows only that Sunday's payments (the week is Monday–Sunday, per AC3), so a bill due Monday isn't counted yet.

`flutter analyze`: no issues · full suite **370/370 passed** (66 new in Sprint 5), identical on two runs · schema v5 migration tested from v1–v4.
