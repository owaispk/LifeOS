# PBI-006 — Vault Full-Text Search & Filters

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §1.3; Data model §8.1 |
| Depends on | PBI-002, PBI-004 |
| Status | Ready |

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
