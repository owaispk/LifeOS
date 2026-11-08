# PBI-005 — Vault Home: Folders, People, Tags, Favourites

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.3; UI flow §3.1, §3.2 |
| Depends on | PBI-002 |
| Status | Done |

## User Story
As a **user**, I want my documents organised by folder and by family member so I can find them at a glance.

## Description
- Vault Home: search bar, People chips (Me / Spouse / Child / Parent / +), Expiring Soon strip (data from PBI-008), folder list with document counts, persistent 📸 Scan button
- People profiles: create, edit and delete (soft delete), with name, relation and emoji avatar
- Custom folders: create, rename, choose an icon, soft delete. System folders can't be deleted.
- Folder view and Person view: document list with thumbnail, title, type chip and date
- Tags: several free-text tags per document
- Favourite/pin: pinned documents appear at the top of every list

## Acceptance Criteria
1. Every document belongs to at most one person and one folder, and can have any number of tags.
2. Folder counts update immediately after a document is saved, moved or deleted.
3. Adding a person makes it appear in the People strip, and its view lists only that person's documents.
4. A system folder shows no delete option. Deleting a custom folder moves its documents to "Unfiled" (no data loss).
5. Each empty folder or person view shows an illustrated empty state with a "Scan" action.
6. Nothing in the Vault is more than 2 taps from the bottom bar.

## Grooming Clarifications (2026-11-08, Sprint 2, before development)
- **Search bar:** until full-text search arrives (PBI-006) it filters by title, issuer and tags (`LIKE`). PBI-006 replaces it with FTS5.
- **Expiring Soon strip:** documents with an `expiry_date` in the next 90 days or already expired, soonest first.
  - Colours: red ≤ 7 d, amber ≤ 30 d, grey beyond, each with a text label.
  - The alert ladder and renewal flow stay in PBI-008.
- **People:**
  - Add / edit / soft-delete with name, relation (self, spouse, child, parent, other) and an emoji avatar.
  - The "self" profile can be renamed but not deleted.
  - Deleting a person leaves their documents unassigned (`person_id = null`). Nothing is lost.
- **Folders:**
  - System folders can't be deleted or renamed. Custom folders can be created, renamed, given an icon, and deleted.
  - Deleting a custom folder moves its documents to **Unfiled** (`folder_id = null`).
  - Unfiled appears as a pseudo-folder only while it holds documents.
- **Document sheet:** tapping a document opens a small sheet to edit title, tags, favourite, folder and person. Its "Move" action is the "moved" path in AC2.
  - The full viewer (pinch-zoom, fields, share, trash) remains PBI-007.
- **Thumbnails:** image pages show the first page. PDFs show a type icon until PBI-007 adds PDF rendering.
- **Ordering:** favourites first, then newest first.
- **Routes:** `/vault`, `/vault/folder/:id`, `/vault/person/:id`, `/vault/unfiled`. That keeps everything within 2 taps of the bottom bar.

## Dev & QA Notes (Sprint 2, 2026-11-08)
Code: `lib/features/vault/` — `domain/vault_rules.dart` (pure), `data/vault_service.dart`, `vault_screen.dart` (Vault Home), `vault_list_screen.dart` (folder / person / Unfiled), `ui/` (document tile & sheet, person & folder sheets). Routes `/vault/folder/:id`, `/vault/person/:id`, `/vault/unfiled`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Service test: a document holds one folder + one person (moving replaces both), tags normalised (case-insensitive de-dupe). |
| 2 | ✅ | Widget: counts update after save (insert), move (document sheet → Medical) and delete (sheet → Delete). |
| 3 | ✅ | Widget: Add person "Ali" → appears in the People strip; Ali's view lists only Ali's documents. |
| 4 | ✅ | Service: system folders refuse rename/delete; deleting a custom folder moves its docs to Unfiled with nothing deleted. Widget: no menu on a system folder; deleting "Trips" shows **Unfiled · 1 doc**. |
| 5 | ✅ | Widget: an empty folder shows "Nothing here yet" + **📸 Scan** (opens the capture flow pre-filed to that folder — PBI-003 test). |
| 6 | ✅ | Widget: bottom bar → folder (tap 1) → document sheet (tap 2). |

Also built: interim search (title / issuer / tags, every word must match), Expiring Soon strip (≤ 90 d, red/amber/grey + text label), favourites first, "Me" protected from deletion, deleting a person unassigns their docs and tasks.

`flutter analyze`: no issues · full suite `flutter test`: **204/204 passed** (100 new in Sprint 2), identical on two consecutive runs. 23 tests for this PBI (16 unit/service + 7 widget).
Not verified on a device (no Android SDK yet).
