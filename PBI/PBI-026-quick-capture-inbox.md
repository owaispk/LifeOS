# PBI-026 — Quick Capture Inbox: Dump & Sort Later

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) / E4 Money / E1 Vault |
| Priority | P0 (MVP — daily-use anchor) |
| Story Points | 8 |
| Spec refs | Features §3.1 (quick add), §2.1 (inbox); UI flow §2.1 |
| Depends on | PBI-002, PBI-009, PBI-018, PBI-003 |
| Status | Ready |

## User Story

As a **user on the go**, I want to quickly dump a thought, photo, or receipt without deciding what it is right now, so I can capture it instantly and sort it into tasks, expenses, or documents later when I have time.

## Description

**Quick Capture Inbox** is a frictionless entry point for things that don't fit neatly into one domain yet. It lives as a floating action button (FAB) or a tab, collects incoming captures (text, voice, photo, file), and surfaces them in an **Inbox** where the user reviews, classifies and moves each one to its destination (task, expense, document).

This lowers the barrier to opening the app daily and pairs with PBI-039c (Brain Dump to Plan) for AI-powered sorting later.

## Key Principles

- **No decisions at capture time.** User says/snaps/types something and hits Done. That's it.
- **One inbox, one shot to decide.** Each capture appears in the inbox with a quick-classify menu: *"This is a task / expense / document / note"*.
- **Minimal, fast UI.** The whole capture takes < 3 seconds.
- **Offline-first.** All captures are stored locally in a `captures` table.
- **Reuses existing tools.** Tapping "This is a document" uses the existing document confirm flow (PBI-003). "This is a task" uses PBI-010 NL parser. "This is an expense" uses PBI-018 expense form.

## Acceptance Criteria

### Capture Methods (AC 1–3)
1. **Text quick-add.** A floating action button (⊕) opens a one-line text field ("Add a note…") with a send button. Typing and tapping Done (or Cmd+Return) saves to the inbox. No date parsing, no voice—just plain text.
2. **Voice quick-add.** A 🎤 button in the text field opens the M3 voice overlay (reuses PBI-010's speech-to-text) to capture a paragraph of voice. The transcribed text is saved to the inbox.
3. **Photo/file quick-add.** A 📸 button opens the device's camera or file picker. Snapping or selecting a file (JPEG, PNG, PDF) is saved to the inbox with its original name and media type. The user is not prompted to classify or rename at capture time.

### Inbox View (AC 4–7)
4. **Inbox list.** A dedicated "Inbox" tab (or accessible from More menu) shows all pending captures, newest first, with a count badge on the FAB/tab. Each row shows: capture type icon (📝 text, 🎤 voice, 📸 photo), preview (first 50 chars of text, or thumbnail), timestamp ("2 mins ago"), and a right-swipe menu or action button.
5. **Quick classification.** Tapping a capture or the action button shows a modal with four choices: **Task**, **Expense**, **Document**, **Note**. Tapping one flows to the appropriate form (task NL parser, expense form, document confirm step, or a simple notes field).
6. **Note destination.** If the user chooses **Note**, the capture is moved to a "Notes" section within the capture's own detail card (or a separate Notes list). It is not promoted to a task/expense/document; it stays as-is for later reference or deletion.
7. **Batch actions.** A select-all checkbox lets the user bulk-delete or bulk-classify captures (e.g., "All of these are tasks"). If bulk-classifying, each capture flows through the form (with the text pre-filled) and is either saved or discarded individually.

### Flow & Handoff (AC 8–10)
8. **Task handoff.** Choosing **Task** takes the text to PBI-010's task parser (live preview chips, voice support). The user reviews, edits and saves. The capture is marked done.
9. **Expense handoff.** Choosing **Expense** takes the text to PBI-018's expense form (amount, date, category). If the text contains a number (e.g., "coffee 500"), it is pre-filled in the amount field. The user reviews and saves.
10. **Document handoff.** Choosing **Document** with a photo/file opens PBI-003's confirm step (title, folder, person, tags). If the capture is text, a dialog appears: *"Turn this note into a document? (e.g., a scanned receipt)"* with **Turn into document** / **Keep as note**. If yes, the text is OCR'd into a searchable document; if no, it stays a note.

### State & Cleanup (AC 11–13)
11. **Inbox persistence.** Captures table has: `id, user_id, capture_type (text|voice|photo|file), content (text), media_path (nullable), media_mime, created_at, processed_at (null until moved/noted/deleted), status (pending|done|deleted)`. The inbox shows only `status = pending`.
12. **Mark as done.** After a capture is classified (moved to task/expense/document/note), its status is set to `done` and it disappears from the inbox. The user can undo this action by swiping back or tapping Undo in the snackbar (for 3 seconds).
13. **Delete.** A capture can be deleted from the inbox. Deleted captures are marked `status = deleted` (soft delete, not removed from the table—part of the audit trail). Undo is available for 3 seconds.

### UX & Performance (AC 14–16)
14. **Sub-3-second capture.** From FAB tap to Done, the whole flow (text, voice, or photo) takes < 3 seconds on a mid-range device. No progress bars, no spinners—just capture and save.
15. **Badge & notification.** The Inbox FAB/tab shows a count badge (e.g., "3") for pending captures. An optional notification (enabled by default, togglable in PBI-023 Notification Diet) fires when a capture is added: "📥 1 new capture — tap to sort" (quiet, batched in quiet hours).
16. **Empty state.** When the inbox is empty, show "✓ All clear" with a message: "Captures you add will appear here. Tap ⊕ to start." A visual hint (e.g., a subtle icon animation) encourages use.

### Accessibility & Localization (AC 17–19)
17. **Voice without hands.** In the capture overlay (voice), the transcription is live and readable. Tapping Delete removes the last word; tapping Submit saves.
18. **Urdu + English.** All strings ("Add a note", "Task / Expense / Document / Note", "All clear") are localized. Voice input works in Urdu (`ur_PK` locale).
19. **Screen reader.** The inbox is a list; each capture has a role and accessible label: "Capture 1 of 3: Text note '…', 2 mins ago, pending". The FAB has a label "Add capture" and an announcement "3 captures waiting".

### Offline & Edge Cases (AC 20–22)
20. **Offline captures.** All capture methods work offline. Captures are stored in local `captures` table. When the device comes online, nothing special happens (no auto-sync; that's future, PBI-026c multi-device sync).
21. **Large media.** If the photo or file exceeds 50 MB, a warning appears: *"This file is very large (75 MB) and may slow down the app. Use anyway?"*. The user can retry, compress (for photos), or cancel.
22. **Storage warning.** If device free storage drops below 100 MB, a warning appears when capturing (reuses PBI-003's logic). The user can proceed anyway or cancel.

### Testing (AC 23–25)
23. **Unit tests.** `captures` table schema, soft-delete logic, status transitions (pending → done / deleted), undo, batch ops. Capture data never contains sensitive data (no API keys, no user identifiers injected into content).
24. **Widget tests.** Text/voice/photo capture flows, inbox list with empty and multiple items, quick-classify modal, task/expense/document handoff, bulk actions, swipe undo, badge count.
25. **Integration test.** End-to-end: FAB → text capture → Inbox → Task classification → task parsed → capture marked done → badge count down. Same for voice and photo flows.

## Grooming Notes

### Captures Table (Schema Addition)
```sql
CREATE TABLE captures (
  id TEXT PRIMARY KEY,                 -- UUIDv7
  user_id TEXT NOT NULL,
  capture_type TEXT NOT NULL,          -- 'text' | 'voice' | 'photo' | 'file'
  content TEXT,                        -- text or voice transcription
  media_path TEXT,                     -- local path if photo/file
  media_mime TEXT,                     -- e.g., 'image/jpeg', 'application/pdf'
  media_size_bytes INTEGER,            -- file size
  created_at INTEGER NOT NULL,         -- Unix ms
  processed_at INTEGER,                -- Unix ms, set when moved/deleted
  status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'done' | 'deleted'
  destination_id TEXT,                 -- foreign key: task/expense/document id
  destination_type TEXT,               -- 'task' | 'expense' | 'document' | 'note'
  notes TEXT,                          -- if destination_type = 'note'
  
  FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX captures_status_created ON captures(status, created_at DESC);
```

**Schema version:** increment to v7.

### File Structure
```
lib/features/capture/
  ├── domain/
  │   ├── capture_model.dart           -- Capture, CaptureType
  │   └── inbox_service.dart           -- classification, undo, batch logic (pure)
  ├── data/
  │   ├── captures_repo.dart           -- persist, update, delete, undo (Drift)
  │   └── media_storage.dart           -- save photo/file to app storage
  └── presentation/
      ├── providers.dart               -- Riverpod: inbox list, capture form
      ├── screens/
      │   ├── inbox_screen.dart        -- list, empty state, badge
      │   └── classify_modal.dart      -- Task / Expense / Document / Note
      └── widgets/
          ├── capture_fab.dart         -- floating action button + menu
          ├── text_capture_form.dart   -- one-line text + send
          ├── voice_capture_overlay.dart -- M3 overlay (reuses PBI-010)
          └── photo_capture.dart       -- camera / file picker
```

### Build Order
1. Captures table & schema migration.
2. `captures_repo.dart` (CRUD + soft-delete + undo).
3. Capture FAB + text/voice/photo forms (AC 1–3).
4. Inbox list & empty state (AC 4, 16).
5. Classify modal + handoffs (AC 5–10).
6. Badge & notifications (AC 15).
7. Batch actions (AC 7).
8. Tests (AC 23–25).

### Decisions
- **Where is the Inbox?** Option A: a new tab (Home / Tasks / **Inbox** / Vault / Money / More). Option B: a dedicated screen reachable from Home or FAB. Option C: a persistent bottom sheet (minimal screen real estate). **Recommendation: Option A** — the inbox is important enough to anchor daily retention (like Tasks and Vault). If space is tight, combine Inbox + Tasks into one tab with two sections (Today / Upcoming / Inbox).
- **Classify UI.** Option A: a modal (4 big buttons). Option B: a menu (actions slide up). Option C: a simple segmented control (Tab between Task/Expense/Document). **Recommendation: Option A** — modals are clear and touch-friendly on mobile.
- **Undo duration.** Standard is 3 seconds (quick enough to notice, long enough to tap). Can be extended if device CPU is slow; not configurable by user.
- **Notes storage.** A capture classified as "Note" stays in the same `captures` table with `destination_type = 'note'` and `notes` field set. They do not clutter the main task/expense/document lists. Future work (PBI-040 or later) might promote notes to a Notes app feature; for now they are just Inbox archival.

### Rollout Notes
- **MVP:** All 5 capture methods (text, voice, photo, file, batch) are in.
- **Free tier limits (PBI-029):** Inbox is unlimited; no artificial cap.
- **Notification (PBI-023):** Capture notifications are optional and default on; user can toggle "Inbox" in Settings → Notifications.
- **Quiet hours (PBI-023):** Capture notifications respect quiet hours (deferred to end-of-window).

### Pairs With
- **PBI-010 (Voice Add):** Reuses the speech-to-text overlay and NL parser.
- **PBI-003 (Document Capture):** Reuses the confirm step and file handling.
- **PBI-018 (Expense Log):** Reuses the form.
- **PBI-039c (Brain Dump to Plan):** Future AI can read the inbox and propose multi-step plans ("This voice note looks like a project — break it into tasks?").

## Dev & QA Notes (TBD — Sprint 7 or later, after MVP device QA)

**Prerequisites:**
- PBI-002 deployed (database schema migration tested).
- PBI-003, PBI-010, PBI-018 working and stable.
- Speech-to-text working (PBI-010 device QA complete).

**Testing strategy:**
- Unit tests for `captures_repo`, `inbox_service`, `media_storage` (pure and with fakes).
- Widget tests for text/voice/photo capture, inbox list, classify modal, handoffs.
- Integration test with a mock task/expense/document service.
- Device QA: end-to-end capture on a real phone, undo, batch ops.

**Performance baseline:**
- Capture save: < 100 ms (local Drift insert).
- Voice transcription: device-dependent, typically 2–5 s.
- Inbox list render: < 500 ms for 50 captures.

**Known challenges:**
- Voice transcription may be slow on older devices; consider a loading spinner if transcription takes > 3 s (AC14 allows up to 3 s total, but the NL parser and form creation add time).
- Large media (AC21) should be handled gracefully; consider background compression for photos.

| AC | Result | Status |
|---|---|---|
| 1–3 | Text / voice / photo capture | Ready for dev |
| 4–7 | Inbox list, classify, batch | Ready for dev |
| 8–10 | Handoffs to task/expense/document | Ready for dev (depends on 003, 010, 018 stable) |
| 11–13 | Persistence, undo, delete | Ready for dev |
| 14–16 | Performance, badge, UX | Ready for dev |
| 17–19 | A11y, localization | Ready for dev |
| 20–22 | Offline, edge cases | Ready for dev |
| 23–25 | Tests | Ready for dev |

**Estimated device QA:** 1–2 hours (capture methods, handoffs, batch undo on a real phone).

---

**Status:** Ready to add to MVP backlog. Recommend moving to Sprint 7 (or parallel track if team capacity allows) because it depends on stable 003, 010, 018, but does not block any of them.
