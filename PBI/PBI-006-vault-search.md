# PBI-006 — Vault Full-Text Search & Filters

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.3; Data model §8.1 |
| Depends on | PBI-002, PBI-004 |
| Status | Done |

## User Story
As a **user**, I want to type "passport" or "K-Electric 4500" and find the document instantly, even inside its text.

## Description
- SQLite **FTS5** virtual table `documents_fts(title, issuer, ocr_text)`, kept in sync by triggers
- Search-as-you-type with prefix matching and result snippets that highlight the match
- Filters: person, document type, date range, "expiring soon"
- Filters combine (AND) with the text query

## Acceptance Criteria
1. With 500 seeded documents, results appear in under 1 s on a mid-range device, offline (measured in an integration test).
2. A term that appears only in `ocr_text` still finds the document.
3. "K-Electric 4500" matches a document whose issuer is K-Electric and whose OCR text contains 4500.
4. Soft-deleted documents never appear in results.
5. Editing a document's title or OCR text updates search results immediately (trigger test).
6. Clearing the query and filters returns to Vault Home.

## Grooming Clarifications (2026-11-08, Sprint 3, before development)
- **Index:** schema v3 adds an SQLite FTS5 table `documents_fts(title, issuer, ocr_text, tags)` with `unicode61` tokenisation.
  - It's an external-content table over `documents.rowid`.
  - Insert / update / delete triggers keep it in sync.
  - It's built from existing rows during the migration.
- **Query:**
  - Each word becomes a prefix match (`word*`), and all words must match (AND).
  - Results join back to live documents; soft-deleted ones are excluded. Archived documents stay searchable (needed by PBI-008).
  - Ranking is by `bm25`.
  - Snippets come from FTS5 `snippet()` with the match marked, shown bold.
- **Filters:** chips that combine with the query (AND). A filter can also be used without a query.
  - Person.
  - Type.
  - Added date: last 30 days, this year, or any time.
  - Expiring soon (≤ 90 days or expired).
- **UI:** replaces PBI-005's interim search in Vault Home. Clearing the query and all filters returns to Vault Home.
- **AC1:** an integration test seeds 500 documents with realistic OCR text and times a query on the development machine.
  - It must take under 1 s.
  - The same check on a mid-range phone is device QA.

## Dev & QA Notes (Sprint 3, 2026-11-09)
Code:
- `lib/data/db/search.drift`: FTS5 table + 3 sync triggers. Schema v3, with a tested v1/v2 → v3 migration that rebuilds the index for existing documents.
- `lib/features/vault/data/search_service.dart`
- Vault search bar + filter chips + highlighted snippets.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ (dev machine) | 500 seeded documents, 2 queries: **15 ms** in total (budget 1 s). The same check on a mid-range phone is device QA. |
| 2 | ✅ | A word found only in `ocr_text` finds the document, including prefixes ("national" → "Nationality"). |
| 3 | ✅ | "K-Electric 4500" matches issuer K-Electric + OCR "Rs. 4,500". Numbers also match their thousands-separated form. |
| 4 | ✅ | Soft-deleted documents never appear. |
| 5 | ✅ | Changes to title or OCR text show up in results immediately (trigger tests, service + widget). |
| 6 | ✅ | Widget: **Clear** resets the query and all filters and returns to Vault Home. |

Filters: person, type, added (30 days / this year), expiring soon. They combine with the query (AND) or work alone. Archived documents stay searchable. Snippets come from the document text only, so they never repeat the title.

`flutter analyze`: no issues · full suite **245/245 passed** (41 new in Sprint 3), identical on three runs. 11 tests for this PBI (8 service + 3 widget).
