# PBI-022 — Onboarding (First Value in 2 Minutes)

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §13; UI flow §0.2 |
| Depends on | PBI-003, PBI-013, PBI-019 |
| Status | Ready |

## User Story
As a **new user**, I want to get value within 2 minutes, without creating an account.

## Description
1. Role picker: Student / Professional / Parent / Business owner / Just me (tunes default copy and ATC suggestions)
2. "Scan your first document" (guided) or Skip
3. "What do you pay every month?": chips (Rent · Electricity · Gas · Internet · School fee · Mobile · Installment · + Custom). Each chip expands to amount + day, then shows ⚡ "Auto-reminder on".
4. Done: the first Monthly Forecast + "See my dashboard". The notification permission is asked here, in context.

No account is required (local mode). Steps 2–4 are skippable.

## Acceptance Criteria
1. Onboarding shows only on first launch and never again after completion or skip.
2. Each completed chip creates an active ATC rule (PBI-013).
3. The final screen shows a forecast total equal to the sum of the entered amounts.
4. Camera and notification permissions are never requested before steps 2 and 4.
5. The whole flow, with 2 payment chips and a skipped scan, can be completed in under 2 minutes (usability check).
