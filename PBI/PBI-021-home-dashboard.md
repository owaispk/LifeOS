# PBI-021 — Home Dashboard

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §10; UI flow §1, §1.2 |
| Depends on | PBI-020, PBI-009, PBI-008, PBI-019 |
| Status | Ready |

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
