# PBI-003 — Document Capture (Scan & Import)

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §1.1; UI flow §3.4 steps 1–2 |
| Depends on | PBI-002 |
| Status | Done |

## User Story
As a **user**, I want to scan any paper with my camera so it becomes a clean digital document.

## Description
- Camera scan with auto edge detection, auto-crop and perspective correction (ML Kit Document Scanner)
- Enhance modes: Original / Doc (high contrast) / Grayscale
- Multi-page scanning merged into one PDF
- Import from gallery and files (images + PDFs). Receive "Share to LifeOS" intents from other apps (e.g. WhatsApp).
- Batch mode: scan several documents in one session and file them afterwards
- Camera permission is requested **in context**, on first scan

## Acceptance Criteria
1. Scanning one page and tapping Save creates a `documents` row plus a `document_files` row in **under 10 s** on a mid-range device.
2. Multi-page scans produce one PDF with pages in capture order.
3. Output can be PDF (default) or JPEG.
4. The whole flow works in airplane mode.
5. A blurry capture (sharpness below threshold) prompts "Retake? Image looks unclear".
6. With less than 100 MB free storage, a warning appears before the scan session starts.
7. Re-scanning an identical document (same image hash, or the same issuer + ref + period) prompts "Looks like a duplicate of '<title>'. Keep both?"
8. Sharing a PDF from another app into LifeOS opens the classify/confirm step.

## Out of Scope
OCR/classification (PBI-004), encryption (PBI-024).

## Grooming Clarifications (2026-11-08, Sprint 2, before development)
- **Scanner:** the platform's native document scanner via `cunning_document_scanner` (ML Kit on Android, VisionKit on iOS).
  - It provides edge detection, auto-crop, perspective correction, enhance filters and multi-page capture.
  - It runs on-device and offline.
  - The camera permission is handled by the scanner when you first scan, so it's requested in context.
- **Import:** `file_picker` for images (jpg, png) and PDFs.
- **Share-in:** `receive_sharing_intent` (Android intent filters for images and PDFs). A shared file opens the confirm step with `source = share_in`.
- **Output:**
  - **PDF (default):** all pages merged into one PDF.
  - **JPEG:** one `document_files` row per page (`image/jpeg`).
  - Imported PDFs are stored as they are.
- **Storage:**
  - Files are copied into the app's documents directory: `vault/<documentId>/<fileId>.<ext>`.
  - `document_files` records `local_path`, `byte_size`, `sha256` and `mime`.
  - Encryption at rest is PBI-024.
- **Blur check:**
  - Measured as the variance of the image's edge (Laplacian) response on a downscaled grey copy; a low value means a blurry image.
  - Below the threshold the user sees "Retake? Image looks unclear" with **Retake** / **Keep anyway**.
  - Pure Dart, with unit tests that use generated sharp and blurred images.
- **Low storage:** under 100 MB free, a warning is shown before the scan session, with **Scan anyway**.
- **Duplicates** (a new `document_files.phash` column in schema v2). Before saving, a 64-bit perceptual "difference hash" of the first page is compared with existing documents.
  - A match is a near-identical hash, or the same issuer + reference number + period (once PBI-004 fills those fields).
  - The user is then asked "Looks like a duplicate of '<title>'. Keep both?"
- **Batch mode:** after each scan, **Scan another** adds it to a session tray. **Review & file** then walks through each item's confirm step.
- **Confirm step (before PBI-004):**
  - Fields: title (default "Scan · 8 Nov 2026"), folder, person, output format.
  - Then **Save to Vault**.
  - PBI-004 adds type detection and field extraction to this same screen.
- **Device-only ACs:** AC1 (under 10 s on a mid-range device) and the native camera flow need an Android emulator or device, so they're *Pending device QA*. Everything around them is tested with fake scanner, picker and storage services: PDF building, saving, blur check, duplicates, low storage, batch and share-in.

## Dev & QA Notes (Sprint 2, 2026-11-08)
Code: `lib/features/capture/`:
- `domain/image_checks.dart`: blur score and perceptual hash
- `domain/pdf_builder.dart`
- `data/capture_service.dart`: save, duplicates, files
- `platform/capture_platform.dart`: scanner / picker / storage / share-in interfaces and plugin implementations
- `capture_entry.dart`: the flow
- `review_screen.dart`: Review & file
- `share_in_listener.dart`

Every Scan button (Vault, FAB, Home, empty folders) and Vault's Import use this flow. Schema v2 adds `document_files.phash` (migration tested). Android share intent filters are added.

| AC | Result | Evidence |
|---|---|---|
| 1 | ⏳ Device QA | Save path is exercised end-to-end in tests (rows + files written, SHA-256 matches). The "under 10 s on a mid-range device" timing needs a phone. |
| 2 | ✅ | Service + widget: a 2-page scan becomes one PDF (`%PDF-`, pages in capture order) in `vault/<docId>/`. |
| 3 | ✅ | PDF is the default. **JPEG** stores one `image/jpeg` file per page; PNG pages are re-encoded. |
| 4 | ✅ (by design) | No network code anywhere in capture: scanner, PDF, hashing and storage are all on-device. Airplane-mode run is part of device QA. |
| 5 | ✅ | Blur check on generated pages: sharp scores 8,600+, unreadable blur under 50, threshold 100. Widget: a blurry page asks "Retake?"; **Retake** reopens the scanner, **Keep anyway** continues. |
| 6 | ✅ | Widget: 42 MB free → "Storage is almost full… Only 42 MB free"; Cancel never opens the scanner, **Scan anyway** does. |
| 7 | ✅ | Service: a resized, brighter re-scan matches (≤ 6 bits); different docs and deleted docs don't; same issuer + ref + period matches. Widget: "Looks like a duplicate of 'Electricity Bill Oct'. Keep both?" → Discard new keeps 1 doc. |
| 8 | ✅ | Widget: a shared PDF opens Review & file (no format choice, stored as-is, `source = share_in`, inbox reset). |

Also built:
- Batch mode: **Scan another**, then "1 of 2".
- Import from files: each PDF becomes its own document; images are grouped into one.
- Scanning from a folder files the document into that folder.
- Cancelling the scanner changes nothing.
- A failed save leaves no files and no rows.

`flutter analyze`: no issues · full suite `flutter test`: **204/204 passed** (100 new in Sprint 2), identical on two consecutive runs. 30 tests for this PBI (19 unit/service + 11 widget).

**QA findings fixed:**
- A background-isolate call captured the database connection and crashed. It now runs in a top-level helper that captures only the bytes.
- Stacked snackbars hid the latest result. The newest message now replaces the old one.

**Not verified:**
- The native scanner UI, file picker and share sheet. They're behind interfaces with fakes in tests; real runs need Android.
- The blur threshold is calibrated on synthetic pages and should be re-checked on real phone scans.

## Device QA (2026-11-09)
Android emulator `sdk gphone64 x86 64`, Android 17 (API 37), Google Play services; debug APK; 2026-11-09.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | ML Kit Document Scanner (native camera UI) captured a page from the emulator camera → confirm step → **Save → "Saved to Vault" in 3.3 s**, including ~1 s of measurement polling (limit 10 s). A PDF was written to the app's private `vault/<docId>/` folder and the document appeared in its folder. |
| 4 | ✅ | Scanning and saving use no network: the module was already installed, and the Vault worked with airplane mode on. |

Notes:
- The first scan triggers a one-time Google Play services download of the scanner module, which needs a connection.
- A scan with no text correctly falls back to "Unclassified".

## Change (2026-11-10): stricter duplicates, batch review

Device scanning showed the AC7 check firing on documents that were not duplicates, and the batch flow ("1 of 2") made a multi-document session hard to steer. Both were reworked in `329b72c`.

**Duplicates (AC7).** A near page-1 image hash on its own was too coarse: a mostly white page shrinks to its layout, so this month's bill and last month's bill from the same company hashed within the 6-bit threshold and were offered as duplicates of each other. The check is now:
- Both documents read by OCR → the hashes must be near (≤ 6 bits) **and** the texts must agree. Of the number tokens — amounts, dates, reference and meter readings, the things that change between two documents built from one template — at least 80% shared, and of the words at least 60%. A page with fewer than 3 numbers is judged on words alone, at 85%.
- Either side unread → the hash must be nearly identical (≤ 2 bits).
- Same issuer + reference + period still matches, unchanged.

The dialog now also says when the older document was saved: "Looks like a duplicate of 'Electricity Bill Oct', saved 12 Oct. Keep both?"

Code: `domain/duplicate_check.dart` — pure Dart, 5 unit tests.

**Batch review.** Two or more documents in a session now show as a list, newest first and marked New, each card carrying its own status; a single document still opens its form directly.
- Every scan is read in the background as soon as it is added, so a card is usually ready by the time it is opened.
- **Save ready documents** files everything that is read and typed, in one tap.
- A possible duplicate is held back and flagged "May be a duplicate of '<title>'" instead of being filed or discarded. The user opens it and decides.
- Edits live in the session, so opening a card and going back keeps them.
- Discarding can be undone.
- Scan another / Import are labelled buttons; tapping a page opens it full screen.

Code: `capture_providers.dart` (`DraftEntry`, `DraftEdits`), `review_screen.dart`.

**Blurry pages (AC5).** The warning now names the page ("Page 2 looks unclear — text may be hard to read later"), and in a multi-page scan the unclear pages can be removed while the rest are kept.

**Scope note:** the batch list, the per-card status, held-back duplicates and undo go beyond this PBI's Description, which asks only to "scan several documents in one session and file them afterwards". They are recorded here rather than in a PBI of their own; if the backlog wants them tracked separately they are a candidate for PBI-036.

`flutter analyze`: no issues · full suite `flutter test`: **557/557 passed**.

**Not verified:** the stricter duplicate rule and the batch list have not been through a device pass. Both are exercised only against fake scanner output, so they belong in the next device QA session alongside PBI-033.
