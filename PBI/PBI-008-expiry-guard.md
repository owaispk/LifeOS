# PBI-008 — Expiry Guard

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.4; UI flow §3.6; Data model §6.5 |
| Depends on | PBI-002, PBI-012 |
| Status | Done (alert delivery on device covered by PBI-012 device QA) |

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

## Grooming Clarifications (2026-11-08, Sprint 4, before development)
- **Ladder** (pure; whole days before expiry, reminders at 09:00 local):
  - Passport / visa: 180, 90, 30.
  - Bill: 3, 0, then overdue +1 day.
  - Everything else: 90, 30, 7, 1.
  - `expiry_alerts` (JSON list of days) overrides the default.
  - Only reminders still in the future are created. A passport 200 days out gets exactly 180/90/30.
- **Mechanism:** each document with an expiry gets one hidden-intent **renewal task**:
  - domain `vault`, `source_document_id` = the document, title "Renew <title>", all-day on the expiry date
  - its reminders follow the ladder

  PBI-012 already sends these as generic "A document expires soon" notifications. Setting or changing the date rebuilds the reminders (no duplicates), and clearing it removes the task.
- **Expired and ignored:** after expiry there are no more ladder reminders; a single weekly nudge fires (next Sunday 18:00), rebuilt at app start. That's at most one per week. The digest notification itself is PBI-023.
- **Expiring Soon screen:** `/vault/expiring`, from the strip's "See all".
  - Sorted ascending.
  - Excludes deleted and archived documents.
  - Colours: red ≤ 7 d, amber ≤ 30 d, grey beyond, each with a text label.
- **Renewal:**
  - In the viewer, **Mark renewed** starts a scan pre-filed to the same folder and person.
  - On save, the old document gets `archived_at` + `renewed_by_id`, and its renewal task is removed.
  - Both documents stay searchable.
- **"Does this document expire?":** a one-time card in the viewer for ID, licence, warranty and policy types that have no date.
  - Answering **Set date** or **No** records `expiry_prompted_at` (schema v4), so it never asks again.
- **Notifications:** never include document numbers or names (PBI-012 planner rule, re-tested here).

## Dev & QA Notes (Sprint 4, 2026-11-09)
Code:
- `lib/features/vault/domain/expiry_ladder.dart` (pure).
- `data/expiry_guard.dart`: idempotent reconcile, run at start, on document changes and on resume.
- `expiring_screen.dart` (`/vault/expiring`).
- Viewer additions: ladder line, **Mark renewed**, and the one-time prompt.
- Schema v4 `documents.expiry_prompted_at`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | A passport 200 days out → one renewal task + exactly 3 reminders: 28 Nov, 26 Feb, 27 Apr, all 09:00. |
| 2 | ✅ | Changing the date to 31 Jan 2027 leaves only the still-future 30-day alert; repeated reconciles add nothing; the renewal task moves rather than duplicating. |
| 3 | ✅ | Widget: Expiring Soon lists ["Passport (Ali)", "Visa"], soonest first, without the archived and deleted documents. |
| 4 | ✅ | Expired documents get no ladder; only the most overdue one carries a single Sunday 18:00 nudge, so at most one per week. |
| 5 | ✅ | Planner: expiry notifications are "A document expires soon" and contain neither the number nor the name. |
| 6 | ✅ | Widget: **Mark renewed** → scan → save → the old document is archived with `renewed_by_id`. Service: its renewal task moves to the new document, and search finds both. |
| 7 | ✅ | Ladder maths covered for leap years (29 Feb), month ends (31 Jan / 31 Mar) and "after expiry" (−1). |

Also: "Does this document expire?" appears once (ID, licence, warranty, policy), and the viewer shows "Alerts: 180, 90, 30 days before · Next: Sat, 28 Nov".

Delivering these alerts on a phone relies on PBI-012 (device QA).

`flutter analyze`: no issues · full suite **304/304 passed** (59 new in Sprint 4), identical on three runs · web build compiles. 15 tests for this PBI (11 unit/service + 4 widget).
