# PBI-004 — On-Device OCR, Classification & Field Extraction

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 13 |
| Spec refs | Features §1.2; UI flow §3.4 step 3; Data model `extracted_fields` |
| Depends on | PBI-003 |
| Status | Done |

## User Story
As a **user**, I want the app to recognise what I scanned so I don't have to name and file it manually.

## Description
- On-device OCR with Google ML Kit Text Recognition; the full text goes into `documents.ocr_text`
- A rule-based classifier (keyword + regex scoring) for: cnic, passport, visa, license, bill, fee_voucher, receipt, prescription, report, degree, certificate, warranty, policy, agreement, other
- Per-type field extractors:
  - **Bill:** issuer, amount, due date, billing month, reference no.
  - **ID/Passport:** name, number, expiry
  - **Fee voucher:** institution, student name, amount, due date
  - **Prescription:** date, doctor
  - **Warranty/Policy:** product, start, end
- Auto-title, e.g. "K-Electric Bill — Nov 2026"
- Auto-choose the folder from the type, with a manual override
- Classify screen: a type chip with confidence, plus editable fields that slide in as they're extracted
- Per-issuer learning: user corrections are stored (`extracted_fields.corrected = true`) and applied on the next extraction for that issuer

## Acceptance Criteria
1. When confidence is below 0.7, the user is asked to pick the type and no type chip is preselected.
2. Every extracted field is editable before saving. Nothing is saved without the user tapping **Save to Vault**.
3. Extraction runs offline. It handles English text and both Western and Urdu/Eastern-Arabic numerals.
4. On a test set of at least 20 sample bills/IDs (fixtures in `test/fixtures/ocr`), type accuracy is ≥ 85% and amount/due-date accuracy is ≥ 80%.
5. Unreadable documents (no text) are saved as "Unclassified" with type `other`, and the user can tag them manually.
6. After the user corrects a field for issuer X, the next document from issuer X uses the corrected mapping (tested).
7. The classifier and extractors are pure Dart and unit-tested without a device.

## Out of Scope
Cloud LLM fallback (premium, PBI-027).

## Grooming Clarifications (2026-11-08, Sprint 3, before development)
- **OCR engine:** `google_mlkit_text_recognition` (on-device, offline) behind a `TextRecognizer` interface. Tests use recorded OCR text instead of a camera.
- **What gets read:**
  - Scanned or imported *images*: every page, joined in order.
  - Imported/shared *PDFs* aren't OCR'd in the MVP. Reading a PDF's text layer needs a native library. They're saved as "Unclassified" and the user picks the type.
- **Classifier:**
  - Keyword + pattern scoring per type.
  - Confidence = top score's share of all scores, adjusted for how far it leads the runner-up, clamped to 0–1.
  - Below 0.7, no type is preselected and the user must pick one.
- **Extractors:** regex-based, after normalising Urdu/Arabic digits (shared with `Money`):
  - **Dates:** 14/11/2026, 14-11-2026, 14 Nov 2026, Nov 14, 2026, 14-NOV-26.
  - **Amounts:** "Rs", "PKR", "Amount payable", "Total".
  - **Billing month:** "Bill Month: NOV-26" / "November 2026".
  - **Reference:** labelled "Reference / Consumer / Account / Customer ID".
  - **CNIC:** 12345-1234567-1.
  - **Passport:** AB1234567.
  - **Names:** after "Name" / "Student".
- **Known issuers:** K-Electric, LESCO, IESCO, MEPCO, PESCO, SSGC, SNGPL, PTCL, StormFiber, Nayatel, Jazz, Zong, Telenor, Ufone, WASA. Otherwise the first meaningful line.
- **Auto-title:**
  - "<Issuer> Bill — Nov 2026" for bills.
  - "<Type> — <Name>" for IDs.
  - "Unclassified · 8 Nov 2026" when no text was found.
- **Folder:** set automatically from the type, unless the user already chose one (or the scan started from a folder):
  - cnic, passport, visa, license → Identity
  - degree, certificate, fee_voucher → Education
  - prescription, report → Medical
  - bill, receipt → Bills & Receipts
  - warranty, policy → Insurance
  - agreement → Property
- **Confirm screen** (the existing Review & file screen):
  - A type chip with confidence %, or a type picker.
  - Every extracted field is an editable text field.
  - Nothing is written until **Save to Vault**.
- **What's stored:**
  - On the document: `ocr_text`, `doc_type`, `classification_confidence`, `issuer`, `ref_number`, `amount_minor`, `due_date`, `period_month`, `issue_date`, `expiry_date`.
  - One `extracted_fields` row per field. `corrected = true` when the user changed the value.
- **Per-issuer learning (no new table):**
  - When a corrected field exists for issuer X, the label in front of the corrected value on its OCR line (e.g. "Payable within due date") is remembered.
  - The next extraction for issuer X prefers the value after that label.
- **AC4 fixtures:** 24 OCR-text fixtures in `test/fixtures/ocr/` (bills, IDs, vouchers, prescriptions, warranties; English plus Urdu digits), each with expected values.
  - They're realistic, but they were written for this project, not read from real scans.
  - Accuracy on real phone scans is checked during device QA.

## Dev & QA Notes (Sprint 3, 2026-11-09)
Code: `lib/features/capture/ocr/`:
- `doc_classifier.dart`: the classifier
- `field_extractor.dart`: extractors, titles, folders, learning
- `issuers.dart`
- `document_analysis.dart`: ML Kit reader and the analysis pipeline

The Review & file screen now shows a type chip with confidence or a picker, editable fields, and an auto-title and folder.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: low-confidence text shows "Not sure what this is — please pick a type." No chip, Save disabled until a type is picked. |
| 2 | ✅ | Widget: every field is an editable text field (dates use a date picker); nothing is in the database before **Save to Vault**. An edited amount is saved and marked `corrected`. |
| 3 | ✅ | Pure Dart, offline. Urdu and Arabic digits are normalised: date, month and amount tests include ۱۸/۱۰/۲۰۲۶. |
| 4 | ✅ on fixtures | 24 fixtures in `test/fixtures/ocr/`: **type 24/24 (100%)**, **amount + due date 26/26 (100%)**, other fields 39/39. |
| 5 | ✅ | No text → `other`, "Unclassified · 8 Nov 2026", saveable. Imported PDFs aren't OCR'd (as groomed). |
| 6 | ✅ | Unit: a correction teaches the label "Current Bill Charges", and the next SSGC bill uses it. Integration: same flow through the database (`hintsForIssuer`). |
| 7 | ✅ | Classifier and extractors are pure Dart: 12 unit tests plus 7 flow tests. |

**Honesty note on AC4:** the fixtures were written together with the extractor, so 100% is optimistic.
- A robustness test damages every fixture the way phone OCR does (misread letters, merged lines, lost colons).
- The first version recovered only **9/26** amounts and due dates. After adding OCR-tolerant label matching it recovers **26/26**, now kept as a regression guard.
- Real-scan accuracy is measured during device QA.

`flutter analyze`: no issues · full suite **245/245 passed** (41 new in Sprint 3), identical on three runs.

## Device QA (2026-11-09)
Android emulator `sdk gphone64 x86 64`, Android 17 (API 37), Google Play services; debug APK; 2026-11-09.

On-device ML Kit OCR, run on 8 photo-like document images (rendered from the fixtures, slightly tilted, blurred and unevenly lit) imported through the app:

| Image | Type (confidence) | Fields read on device |
|---|---|---|
| K-Electric bill | Bill 100% | Rs 4,850 · due 2026-11-14 · Nov 2026 · ref 0400012345678 |
| SSGC bill | Bill 100% | Rs 1,860 · due 2026-11-20 · Nov 2026 · ref 1122334455 |
| LESCO bill | Bill 100% | Rs 2,410 · due 2026-11-21 · Nov 2026 · ref 08 11111 2233445 U *(after fix)* |
| PTCL bill | Bill 100% | Rs 2,999 · due 2026-11-25 · Nov 2026 · ref 021-34567890 |
| Passport | Passport 100% | AB1234567 · issued 2012-01-05 · expires 2027-03-09 |
| CNIC | CNIC 80% | 42101-1234567-1 · 1990-03-12 · expires 2029-06-15 |
| Fee voucher | Fee voucher 96% | The City School · Ali Owais · Rs 12,000 · due 2026-11-05 · challan 2026-11-778 |
| Warranty | Warranty 100% | 2025-08-12 → 2027-08-11 |

Result: type 8/8, and every expected amount, date and number matched. Each image was filed to the right folder (Bills & Receipts, Identity, Education, Insurance).

**Device QA finding, fixed:** LESCO's reference "08 11111 2233445 U" was read as just "11111", the subdivision code shared by neighbouring meters. Two LESCO meters would have merged into one learned rule (PBI-014 AC4), and duplicate detection could misfire. The new `refAfter` keeps space-separated groups whole, without swallowing a following word. 3 new unit tests; re-verified on the device.

Still open: accuracy on photos of real paper documents (needs physical documents, ideally on a phone). The pipeline is now proven on the device.
