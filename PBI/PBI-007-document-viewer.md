# PBI-007 — Document Viewer, Edit, Move & Trash

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | UI flow §3.3; Data model §1.4 |
| Depends on | PBI-005 |
| Status | Done |

## User Story
As a **user**, I want to open a document, check its details and fix or move it.

## Description
- Full-screen viewer with pinch-zoom and page dots for multi-page documents
- Info panel (swipe up): type, person, editable extracted fields, expiry with its alert ladder, tags, linked tasks
- Action bar: Share (OS share sheet, file only) · Edit fields · Move (folder/person) · Archive · Delete
- Delete is a soft delete into a 30-day Trash. Trash supports Restore and Delete forever (with confirmation).

## Acceptance Criteria
1. Multi-page PDFs and JPEGs render, and every page can be reached.
2. Field edits save as soon as the user confirms, and update search and expiry alerts.
3. Delete moves the document to Trash. Restore brings it back with all its fields intact.
4. Items older than 30 days in Trash are purged on app start (tested with a mocked clock).
5. Sharing sends the file through the OS share sheet. Notification and share previews never show document contents.

## Grooming Clarifications (2026-11-08, Sprint 3, before development)
- **Route:** `/vault/doc/:id`. Tapping a document anywhere now opens the viewer; PBI-005's quick sheet becomes the viewer's **Edit** action.
- **Pages:**
  - JPEG pages: `InteractiveViewer` with pinch-zoom, in a `PageView` with page dots.
  - PDFs: `pdfx` (pdfium on Android/iOS) behind a `PdfPagesBuilder`, so tests can stand it in. Real PDF rendering is device QA.
- **Info panel:** a draggable sheet showing:
  - type (editable)
  - person, folder, tags
  - the main extracted fields (issuer, reference, amount, due, expiry), editable
  - linked tasks (tasks whose `source_document_id` is this document)

  Edits save on confirm and update search (FTS triggers). The expiry alert ladder is added by PBI-008.
- **Actions:**
  - **Share:** the OS share sheet via `share_plus`. Files only, with the neutral text "Shared from LifeOS" and no title or contents.
  - **Edit**, **Move**.
  - **Archive:** sets `documents.archived_at` (schema v3). Archived documents leave folder lists but stay searchable.
  - **Delete:** soft delete into Trash.
- **Trash:**
  - Reached from the Vault menu → Trash. Shows deleted documents with days left.
  - **Restore:** clears `deleted_at`; all fields and files come back intact.
  - **Delete forever:** confirmed, then removes the rows (document, files, extracted fields) and the files on disk.
  - Hard deletes are queued to the outbox as `purge`.
- **30-day purge:** runs at app start (`openLocalData`) and is tested with a fixed clock.

## Dev & QA Notes (Sprint 3, 2026-11-09)
Code:
- `lib/features/vault/document_viewer_screen.dart`: full-screen route `/doc/:id`, above the tabs.
- `ui/document_pages.dart`: pages, PDF view, share.
- `trash_screen.dart` and `data/trash_service.dart`.
- `SyncRepository.restore` / `purge`.
- Schema v3 `documents.archived_at`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ JPEG · ✅ PDF (device) | Widget: a 3-page scan shows dots and "1 / 3"; swiping reaches pages 2 and 3; pinch-zoom via `InteractiveViewer`. PDFs route to the pdfx viewer, which a test stands in for; real PDF rendering is device QA. |
| 2 | ✅ | Widget: editing the reference saves on confirm, and search sees the change. Expiry alerts are wired to these edits by PBI-008 (Sprint 4). |
| 3 | ✅ | Delete → "Moved to Trash" (with Undo) → Trash shows "N days left" → **Restore**: title, folder, issuer, tags and files all intact. |
| 4 | ✅ | Fixed-clock test: deleted 38 days ago → purged at start; 7 days ago → kept, "23 days left". Purge removes the files, page rows and extracted fields, and unlinks tasks, payments and expenses without deleting them. |
| 5 | ✅ (logic) · ✅ OS sheet (device) | Share sends only the files, named "Document.pdf" / "Document 2.jpg", with the text "Shared from LifeOS". No title, number or contents. The OS share sheet itself is device QA. |

Also built: Archive / Unarchive (archived documents leave folder lists and counts but stay searchable), linked tasks in the details panel, and **Delete forever** with confirmation.

**QA findings fixed:**
1. The viewer's action buttons overflowed at their fixed height. They now grow with large text.
2. The viewer sat inside the tab shell, where the ➕ button covered its action bar (seen in a rendered screenshot). It's now a full-screen route.

`flutter analyze`: no issues · full suite **245/245 passed** (41 new in Sprint 3), identical on three runs. 11 tests for this PBI (4 Trash service + 7 widget).

## Device QA (2026-11-09)
Android emulator `sdk gphone64 x86 64`, Android 17 (API 37), Google Play services; debug APK; 2026-11-09.

| AC | Result | Evidence |
|---|---|---|
| 1 (PDF) | ✅ | The scanned PDF opens in the viewer and pdfx renders the page on the device. |
| 5 (OS sheet) | ✅ *(after fix)* | The Android share sheet opens with "Sharing 1 file" and the targets Quick Share, Print, Drive, Gemini. |

**Device QA finding, fixed:** the shared file showed its internal name `01a1bec1-a308-….pdf`. Android uses a file's real name and ignored share_plus's `fileNameOverrides`, so the widget test, which fakes the share, couldn't catch it. Sharing now copies files into a cleared temporary `share/` folder as **Document.pdf** / **Document N.jpg** and shares the copies. Re-verified on the device ("Document.pdf"). 3 new unit tests.
