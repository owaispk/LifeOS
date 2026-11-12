# PBI-038 — Testing Feedback (November 2026 test pass)

| Field | Value |
|---|---|
| Epic | Cross-cutting |
| Priority | P1 (post-MVP) |
| Story Points | TBD — sized when the test pass ends and the list is closed |
| Spec refs | Per item |
| Depends on | Per item |
| Status | Open — collecting feedback (not Ready) |

## User Story
As the **product owner testing the app**, I want every gap I notice written down in one place as I go, so nothing is lost and the list can be groomed into work once testing ends.

## Description
- A running log of feedback from hands-on testing. Each item gets an id (`F-01`, `F-02`, …), what was observed or asked for, and what the code does today.
- Nothing here is developed straight from the log. When the test pass ends, each item is either groomed into this PBI's acceptance criteria (small items) or split into its own PBI (anything of 3 SP or more), and the PBI is then sized.

## Feedback Log

| ID | Date | Area | Feedback | Current behaviour | Outcome |
|---|---|---|---|---|---|
| F-01 | 2026-11-11 | Tasks | There is no way to see Completed or Archived tasks. | Completing a task sets `status = 'done'` and stamps `completedAt`, so the data is kept — but every task list is built through `isOpen` (`features/tasks/domain/task_rules.dart`), so done and skipped tasks vanish from view. Tasks have no archive at all; `archivedAt` exists only on vault documents. | Open |
| F-02 | 2026-11-11 | Money | The Money dashboard is not appealing. | The Overview (`features/money/money_screen.dart`) is plain text on a bare background: a centred "Spent" total with a grey delta line, an 8 px segmented category bar, then two flat lists (categories, expenses). No cards, no trend, no income context; unpaid bills are only on the Forecast tab. | Open |
| F-03 | 2026-11-11 | Vault / Premium | On the free tier, every shared document should carry a small line at the bottom promoting the app. | Shares add only the message text "Shared from LifeOS" in the share sheet, which most apps drop. Nothing is drawn on the document itself. The only page stamp is the optional watermark (PBI-028a, `stampWatermark` in `features/vault/data/share_pack.dart`), which is user-chosen and the same on both tiers. | Open |
| F-04 | 2026-11-12 | Capture / OCR | Does the app shrink images for OCR? (Asked while testing.) | No. Scanned JPEGs are stored byte for byte (re-encoded at quality 90, same size, only when they need rotating or aren't JPEG — `_toJpeg` in `features/capture/data/capture_service.dart`), and ML Kit reads the full-size file (`features/capture/ocr/document_analysis.dart`). The only downscaled copies are internal: 512 px for the blur check, 9×8 for the duplicate hash. | Open |
| F-05 | 2026-11-12 | Money / Auto Tasks | Adding a one-off bill due later this month (e.g. 20 Nov) is hard to find. | The Money screen's "Add expense" only takes dates up to today (spent money). A future bill has to be added under More → ⚡ Auto Tasks → Add, with How often = Once — nothing on the Money screen points there. A typed task ("Pay … Rs … on 20 Nov") gives a reminder but stays out of the Forecast and the to-pay total. | Open |
| F-06 | 2026-11-12 | Money / Auto Tasks | A payment marked paid by mistake can't be reversed after the 5-second Undo. | `PaymentService.undo` reverses everything, but only from the 5 s snackbar. After that: the Forecast row shows "Paid" with no action; the expense it logged can't be deleted (`ExpenseService.delete` refuses payment-linked expenses, the button is hidden); the linked task is done and hidden (see F-01). The wrong amount stays in the month's spending. | Open |

## Item Notes

### F-01 — Completed and Archived tasks
- **Completed view:** no schema change needed. A "Completed" list (most recent first, by `completedAt`) can read the existing rows. `TaskService` already has a reopen path (sets `status = 'open'`, clears `completedAt`), so "mark as not done" comes for free.
- **Skipped tasks** are hidden the same way; decide at grooming whether they appear in the same view or stay hidden.
- **Archived tasks:** needs a product decision first — tasks have no archive concept today. Options: (a) drop it, a Completed view covers the need; (b) add `archivedAt` to tasks, mirroring the vault (schema migration, Archive/Unarchive actions, an Archived list).
- **Where it lives:** undecided — a filter or section on the Tasks screen, or a separate screen reached from it.

### F-02 — Money dashboard redesign
Proposals, in suggested order. None needs a schema change — expenses for all months, categories, salary and the forecast are already loaded.
1. **Hero card.** Put the month total in a tinted card. Show the change vs last month as a chip (arrow + text, never colour alone). When a salary is set, add a progress bar: spent of salary, with the amount left.
2. **Six-month trend.** A small bar chart of monthly totals, current month highlighted; tapping a bar switches the month.
3. **Coming up.** The next unpaid bills and the amount still to pay this month, taken from the forecast, with a link to the Forecast tab.
4. **Category breakdown.** Replace the 8 px bar with a donut (total in the centre) or give each category row its own proportional bar. Tapping a category filters the expense list.
5. **Stat tiles.** Daily average, biggest category, bills paid of total.
6. **Expense list.** Group by day with a daily total; show the most recent few with "See all".
- **Compact requirement (2026-11-11):** the redesign must suit small phones with small fonts. Three compact directions were sketched: (A) dense summary — one-row hero, three stat tiles, stacked category bar with legend, day-grouped list; (B) donut with the total in the centre and the legend beside it; (C) trend chart on top, category filter chips, one merged feed of due bills and expenses. **Chosen: A, dense summary** (owner decision, 2026-11-11). B and C are dropped; the six-month trend (proposal 2) is therefore out of the first pass unless re-added at grooming.
- Likely its own PBI (5–8 SP) rather than part of this one. Items 1–3 change the first impression most; 4–6 can follow.
- The Forecast tab has the same plain look (a three-line text card, a dot strip, a flat list) and should be restyled in the same pass.

### F-03 — "Made with LifeOS" footer on free-tier shares
- **What gets it:** the shared copy only, never the original in the vault. Applies to every page of a free-tier share; Premium shares carry no footer (a Premium perk worth naming on the paywall, PBI-029).
- **Where it is built:** there are two share paths today. Bundles and watermarked shares already re-render each page (`SharePackBuilder` in `share_pack.dart`), so the footer can be stamped in that same pass. A plain single-document share (`shareFilesProvider` in `features/vault/ui/document_pages.dart`) sends the original file bytes untouched, so it would have to go through the page renderer too — the bigger part of the work, and it turns a shared image into a PDF or re-encoded JPEG.
- **Look:** one short line, small grey text, bottom edge of each page, kept clear of the content (a thin strip added below the page rather than drawn over it, so nothing on the document is hidden). Text such as "Shared with LifeOS — free on Android and iOS", localised EN/UR, neutral by default (README rule).
- **QR code — decided (owner, 2026-11-11):** the footer carries a small QR code next to the line. It points to one product-site URL that sends the visitor to the Play Store or the App Store by their device (one code works for both, and the target can change without re-issuing the app). Until the final release the URL is a placeholder; the store links are filled in at release. The QR is generated on the device (offline rule) and must stay scannable at the footer's size — test it from a printed page and from a phone screen.
- **Decide at grooming:** the exact wording; whether the share-sheet message changes with it; whether settings exports and the diagnostics log are in scope (suggest not — they are not documents).
- **Check against:** PBI-028a's watermark (the two must not overlap when both are on), the share history record (store that a footer was added), and the shared-file privacy rules from PBI-007 and PBI-024 (temporary copies still deleted).

### F-04 — Downscale pages before storing and OCR
- **Idea:** cap each page at about 2,400 px on its long edge, JPEG quality ~85, in the existing `_toJpeg` isolate step. An A4 page at that size still gives ML Kit text well above its ~16–20 px character height.
- **Expected gain:** roughly 3–5× smaller pages in the vault (and in future backups, PBI-026b), faster OCR, less memory pressure on low-end phones. Not measured — first log the real size of pages the native scanner returns on a test phone.
- **Risks:** small print (bill reference numbers) must stay readable — run the PBI-004 OCR checks on real documents before and after. The full-size original is gone, so zooming into a stored page shows less detail. Existing pages are left as they are (no migration).
- **Scope check:** imported PDFs are untouched; the blur and duplicate checks keep their own small copies.

### F-05 — Make one-off future bills easy to add
- **Options:** (a) the Money screen's add button offers two choices — "Log an expense" (already paid) and "Add a bill to pay" (opens the Auto Tasks form with How often = Once, due date pre-set); (b) an "Add bill" action in the Forecast tab; (c) when a user picks a future date in the expense sheet, offer to turn it into a bill to pay instead of blocking the date.
- **Also:** the Once form asks for a "Due day" (1–31) and takes the next such day; for a one-off a full date picker is clearer and allows a bill next month.
- Ties into F-02 (the redesigned Money overview's "To pay" tile is a natural entry point).

### F-06 — "Mark as unpaid" for a paid payment
- **Fix:** a "Mark as unpaid" action on a paid payment (Forecast row, and the payment's expense row in the Money overview), with a confirm dialog. It runs the same reversal as `PaymentService.undo`: payment back to upcoming, logged expense removed, attached receipt to Trash, linked task reopened, installment count stepped back.
- **Gap to close:** `undo` today needs the in-memory `PaidResult` from the snackbar. The reversal has to be rebuilt from the database instead (expense found by `paymentId`, task by `taskId`; the reopened task must not leave a duplicate next occurrence for repeating tasks).
- **Edge:** an installment rule that ended on its last payment must come back to active.
- Overlaps F-01 (a Completed tasks view would also let the user find the task).

## Acceptance Criteria
To be written at grooming, once the feedback list is closed.
