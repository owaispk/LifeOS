# PBI-008 — Expiry Guard

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.4; UI flow §3.6; Data model §6.5 |
| Depends on | PBI-002, PBI-012 |
| Status | Ready |

## User Story
As a **user**, I want to be warned before any document expires so I never face a last-minute crisis.

## Description
- Any document can carry an `expiry_date` (from OCR or entered manually)
- Default alert ladder: 90 / 30 / 7 / 1 days before expiry
  - Passport/visa: 180 / 90 / 30 days
  - Bills: 3 days before, on the due date, and overdue
  - A per-document override is stored in `expiry_alerts`
- Setting or changing a date regenerates that document's `task_reminders` locally
- Expiring Soon screen sorted by days remaining. Colours: red ≤ 7 days, amber ≤ 30 days, grey beyond.
- Renewal flow: Mark renewed → scan the new document → the old one is archived (kept, not deleted)
- A document with no date gets a one-time gentle prompt: "Does this document expire?"

## Acceptance Criteria
1. Setting a passport's expiry to 200 days away creates exactly 3 reminders (180, 90 and 30 days before).
2. Changing the expiry date replaces the old reminders. No duplicates remain (tested).
3. Expiring Soon lists only documents that aren't deleted or archived and expire within the window, sorted ascending.
4. Expired and ignored documents trigger at most one nudge per week, in the weekly digest.
5. Notification text never includes the document number or name details, e.g. "A document expires soon".
6. Renewing archives the old document and links it to the new one. Both remain searchable.
7. Ladder computation is a pure function with unit tests covering leap years and month ends.
