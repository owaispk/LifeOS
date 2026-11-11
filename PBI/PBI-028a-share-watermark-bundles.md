# PBI-028a — Share Watermark & Document Bundles (on-device)

| Field | Value |
|---|---|
| Epic | E1 Vault |
| Priority | P1 |
| Story Points | 5 |
| Spec refs | Features §1.5 (Watermark option; Share bundles "Degree + CNIC + Photo → one PDF 'Job Application Pack'"; audit trail), §8 Work ("Certificates & CV pack: Vault bundle pre-configured for job applications") |
| Depends on | PBI-007 (share sheet, neutral file names), PBI-024 (in-memory decryption), PBI-025 (EN/UR) |
| Status | Done |

## User Story
As a **user sending my CNIC or degree to an employer or a bank**, I want to stamp it "Shared with ABC Bank for account opening — 10 Nov 2026" and send several documents as one PDF, so a copy can't be quietly reused for something else and I don't send five attachments.

## Description
Both features run **entirely on the phone**: no server, no account, works offline. The spec's Premium table lists only the *expiring links* as Premium, so these two are **free**.

### Watermark
- On Share (single document or bundle), a **"Add watermark"** step: *Shared with* (required, e.g. "ABC Bank"), *Purpose* (optional), and the date (automatic).
- Text: "Shared by {name} with {recipient} for {purpose} — {date}". The name comes from the Me profile; if it's empty, "Shared with…".
- Drawn **diagonally across every page, repeated**, semi-transparent (about 25%), and also as a footer line. It's burned into the image of each page, so it can't be removed by editing the PDF's text.
- Works for image pages and for PDFs. PDF pages are rasterised at 150 dpi, then stamped, so the output is always a new flattened PDF.
- The original in the Vault is **never modified**. The watermarked copy is a temporary share file, deleted when the share sheet closes (PBI-024's no-plaintext-left rule).

### Bundles
- From the Vault, multi-select documents → **"Share as one PDF"**: reorder pages by document, set a title ("Job Application Pack"), optionally add the watermark, then the share sheet.
- **Saved bundle templates:** "Job Application Pack" (Degree, CNIC, CV, Photo) is preset and editable. A user can save their own, e.g. "Visa file". A template remembers *which documents*, not copies, so it always uses the latest version (a renewed CNIC replaces the old one automatically through the renewal link, PBI-008).
- A bundle can also be saved into the Vault as a new document (optional checkbox), filed in a chosen folder.

### Share history (audit trail, on-device part)
- Every share (single, bundle, watermarked or not) adds a local history entry: date, documents, recipient/purpose if given, watermarked yes/no.
- It's visible from the document (Details → "Shared 3 times") and in Settings → Privacy → Share history. It never leaves the phone and is included in the export (PBI-025).

## Acceptance Criteria
1. A watermarked share of a 3-page scan produces a PDF where every page carries the diagonal text and the footer. The text is part of the page image (no selectable text layer with the watermark).
2. The Vault original is byte-for-byte unchanged after any watermarked or bundled share, and no plaintext share file remains after the share sheet closes (file system check).
3. A bundle of 3 documents (one multi-page PDF, two images) produces one PDF with pages in the chosen order, titled as entered, with the neutral file name rule (PBI-007) applied ("Job Application Pack.pdf").
4. A saved template resolves to the current documents. After a CNIC renewal, the template uses the new CNIC.
5. Share history records every share with documents, time and recipient, and shows the count on the document. It's included in Export (PBI-025 AC3).
6. Works with no network. Free tier, no Premium check.
7. EN/UR for every screen, and the watermark text itself renders correctly in Urdu (RTL shaping) when the app is in Urdu.
8. A 10-page bundle with watermark is ready to share in under 5 s on the emulator (performance check), with a progress indicator while it builds.

## Out of Scope
- Cloud links, expiry, PIN, revocation (028b).
- Editing document contents or redaction (blacking out parts). That's a possible follow-up, not in the spec.

## Grooming Notes (2026-11-10)
- **Rendering:** reuse `pdf` (already used by capture, PBI-003) to compose. Use `pdfx` (PBI-007) to rasterise PDF pages, then draw the watermark with `dart:ui` canvas or the `image` package onto each page bitmap. Run it in an isolate.
- **Urdu watermark:** text drawn through Flutter's paragraph shaping on a canvas (not the PDF library's text), so Arabic-script shaping is correct.
- **Schema:** a new local table `share_events` (id, created_at, document ids JSON, recipient, purpose, watermarked, bundle title, kind = file | link) and `bundle_templates` (id, name, document ids JSON, sort). Both are synced tables (they're user data), so 026 picks them up; they're encrypted columns per 026b for recipient and purpose.
- **Entry points:** the document viewer's Share gains "Share with watermark…". The Vault list gets multi-select (long-press) with "Share as one PDF". Work folder documents surface the "Job Application Pack" template first.

## Dev Notes (2026-11-10)
- **Schema v13:** `share_events` (with `shared_at`) and `bundle_templates`, both synced tables. They're in the export (one CSV each) and in "Delete all local data".
- **Builder** (`lib/features/vault/data/share_pack.dart`): pages in document order, PDFs rasterised at 150 dpi (pdfx), and the watermark drawn with Flutter's text engine. That gives correct Urdu shaping, burned into pixels. JPEG encoding runs off the UI thread. The output is a fresh A4 PDF with images only and no text layer.
- **Service** (`share_service.dart`):
  - `shareTempFile` deletes the temporary copy after the share sheet, even on error.
  - Packs follow the `renewedById` chain.
  - The "Job Application Pack" preset picks the latest degree, the latest CNIC, and documents titled CV/resume and photo.
- **Entry points:**
  - Viewer → Share → *Share file* / *Share with watermark…*.
  - Folder and person lists → long-press to multi-select → *Share as one PDF*.
  - Vault → *Share packs* (the preset plus saved packs).
  - Settings → Security → *Share history*.
  - Details shows "Shared N times".
- **Bundle screen:** title, drag to reorder, add/remove documents, optional watermark, *Also save to the Vault* (choose a folder), and *Save as share pack*.
- **Plain shares** are logged in the history too (AC5 "every share").
- **Not done:** the grooming note "Work folder surfaces the Job Application Pack first". The preset sits at the top of *Share packs* instead. Encrypted columns for recipient/purpose come with 026b.

## QA Notes (2026-11-11)
- **Tests:**
  - `test/features/vault/share_pack_test.dart`: AC1 pixels and no `/Font`, AC2, AC3 order, AC7 Urdu RTL, AC8 progress.
  - `test/features/vault/share_flow_test.dart`: viewer watermark flow and history count, multi-select bundle with title and pack, AC4 renewal, AC5 history screen and export, AC2 temporary file removed, watermark wording, untitled-bundle name.
  - `test/core/plaintext_cache_test.dart`: start-up sweep, share_plus cleanup, temporary PDF file.
  - Full suite: 675 passing.
- **Device QA (emulator, Android 17):**
  - AC1: a 3-page PDF plus a CNIC photo became one 4-page PDF, each page stamped diagonally with the footer line. Confirmed in the in-app viewer and the system print preview.
  - AC3: picked order kept; the share sheet shows one file, "Job Application Pack.pdf".
  - *Also save to the Vault* files the bundle in the chosen folder.
  - AC7: in Urdu the screens mirror, and the watermark reads correctly right to left with "ABC Bank" embedded.
  - AC8 (release build): 10 watermarked pages in 3.4–4.2 s over four runs; without a watermark 0.9–2.1 s. "Preparing… x of y pages" shows throughout.
  - AC2: after a share the app cache holds no plaintext (checked with `run-as`).
- **Found and fixed during device QA:**
  1. share_plus keeps its own copy of every shared file in `cache/share_plus/`, and pdfx's `openData` leaves a decrypted `.pdf` in the cache for every PDF it opens (the viewer too, since PBI-007). Shares now clear share_plus's copy once the sheet closes. PDFs open from a private temporary file that is deleted at once. A start-up sweep removes leftovers, including old `file_picker` import copies (`lib/core/plaintext_cache.dart`).
  2. Too slow at first (≈1 s per page). Pages now render as JPEG, are stamped four at a time while the next page renders, and use 4:2:0 JPEG.
  3. An untitled bundle saved to the Vault was named "Title". It is now "Shared PDF · {date}".
  4. "Shared by Me" (the seeded profile name) now falls back to "Shared with…".
- **Build fix:** the Android build was broken since PBI-032. `device_calendar` 3.9.0 uses Flutter's removed v1 plugin API. Upgraded to 4.3.3, with a `timezone ^0.11.2` dependency override (4.3.3 pins ^0.9; the API it uses is unchanged). Calendar tests pass.
- **Noticed, not in scope:** CNIC OCR took the date of birth as the issue date (PBI-004). A re-shared watermarked bundle gets a second watermark on top, as expected.
