# PBI-022 — Onboarding (First Value in 2 Minutes)

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §13; UI flow §0.2 |
| Depends on | PBI-003, PBI-013, PBI-019 |
| Status | Done |

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

## Grooming Notes (Sprint 6, 2026-11-09)
**Route and trigger:** `/onboarding`. The router redirects to it while `app_meta.onboarding_done` is missing. Finishing or skipping sets it (AC1). Tests seed it as done unless a test is about onboarding.

**Steps**
1. Role picker. Saved to `app_meta.role`; it orders the payment chips (Parent → School fee first; Student → Mobile and Internet first).
2. Scan your first document (opens the real scanner) or Skip. The camera permission comes only from the scanner, here.
3. "What do you pay every month?" Chips expand to amount + day of month, then show ⚡ "Auto-reminder on". Each completed chip creates an active rule through `AtcService.createRule`; Electricity / Gas create `utilities` rules with the amount optional. The free-plan limit applies (3 rules), and the 4th chip says so.
4. Done: the November forecast total and "See my dashboard". The notification permission is requested here, through the gateway (AC4).

**AC3:** the total = the sum of the amounts entered, and it's the same value Money → Forecast shows for this month's generated payments.

**AC5:** a widget test runs the flow (2 chips, skipped scan) in a handful of taps. Real timing is checked by hand on the emulator.

## Dev & QA Notes (Sprint 6, 2026-11-09)
Code:
- `lib/features/onboarding/onboarding_screen.dart`: role → scan or skip → payment chips → done, at `/onboarding`.
- The router redirects there until `app_meta.onboarding_done` is set.
- Installs that already have data (Sprint 1–5) skip it automatically.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: a first launch opens onboarding, not Home. After finishing, a cold restart goes to Home. Unit: an empty install isn't marked; an install with data is. |
| 2 | ✅ | The Rent (Rs 45,000, 1st) and School fee (Rs 12,000, 5th) chips each create an active rule. The 4th chip on the free plan shows the 3-rule limit and creates nothing. |
| 3 | ✅ | "December fixed payments: Rs 57,000" = 45,000 + 12,000. It uses the forecast of the first full month ahead, since rent on the 1st set up on 8 Nov first falls in December. |
| 4 | ✅ | The scanner is called 0 times and the notification permission requested 0 times before steps 2 and 4. The permission is requested exactly once on the final screen. |
| 5 | ✅ | Widget flow: role, Skip, 2 chips × (amount, day, Turn on), Next, See my dashboard, which is about 12 taps. |

Role tuning: Parent → School fee first; Student → Mobile, Internet first; Business → Rent, Electricity, Internet first.

`flutter analyze`: no issues · full suite **457/457 passed**, identical on two runs · schema v6 migration tested from v1–v5 · device checks on the Android 17 emulator (2026-11-09).
