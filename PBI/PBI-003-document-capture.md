# PBI-003 — Document Capture (Scan & Import)

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §1.1; UI flow §3.4 steps 1–2 |
| Depends on | PBI-002 |
| Status | Ready |

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
