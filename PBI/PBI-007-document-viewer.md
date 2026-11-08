# PBI-007 — Document Viewer, Edit, Move & Trash

| Field | Value |
|---|---|
| Epic | E1 Document Vault |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | UI flow §3.3; Data model §1.4 |
| Depends on | PBI-005 |
| Status | Ready |

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
