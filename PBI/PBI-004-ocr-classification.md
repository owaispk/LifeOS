# PBI-004 — On-Device OCR, Classification & Field Extraction

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 13 |
| Spec refs | Features §1.2; UI flow §3.4 step 3; Data model `extracted_fields` |
| Depends on | PBI-003 |
| Status | Ready |

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
