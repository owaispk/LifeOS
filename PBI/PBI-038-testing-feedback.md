# PBI-038 — Testing Feedback (November 2026 test pass)

| Field | Value |
|---|---|
| Epic | Cross-cutting |
| Priority | P1 (post-MVP) |
| Story Points | 13 (F-01 2 · F-02 5 · F-03 3 · F-04 1 · F-05 1 · F-06 1), sized at fix time 2026-11-12 |
| Spec refs | Per item |
| Depends on | Per item |
| Status | F-01–F-06 dev complete (2026-11-12) — device QA pending; the log stays open for new feedback |

## User Story
As the **product owner testing the app**, I want every gap I notice written down in one place as I go, so nothing is lost and the list can be groomed into work once testing ends.

## Description
- A running log of feedback from hands-on testing. Each item gets an id (`F-01`, `F-02`, …), what was observed or asked for, and what the code does today.
- Nothing here is developed straight from the log. Each item is groomed into this PBI's acceptance criteria before it is built. F-01 to F-06 were groomed and built on 2026-11-12 at the owner's request ("fix the feedback", all six done here rather than split with the design-system slices); new items start again as Open.

## Feedback Log

| ID | Date | Area | Feedback | Current behaviour | Outcome |
|---|---|---|---|---|---|
| F-01 | 2026-11-11 | Tasks | There is no way to see Completed or Archived tasks. | Completing a task sets `status = 'done'` and stamps `completedAt`, so the data is kept — but every task list is built through `isOpen` (`features/tasks/domain/task_rules.dart`), so done and skipped tasks vanish from view. Tasks have no archive at all; `archivedAt` exists only on vault documents. | Done (dev) |
| F-02 | 2026-11-11 | Money | The Money dashboard is not appealing. | The Overview (`features/money/money_screen.dart`) is plain text on a bare background: a centred "Spent" total with a grey delta line, an 8 px segmented category bar, then two flat lists (categories, expenses). No cards, no trend, no income context; unpaid bills are only on the Forecast tab. | Done (dev) |
| F-03 | 2026-11-11 | Vault / Premium | On the free tier, every shared document should carry a small line at the bottom promoting the app. | Shares add only the message text "Shared from LifeOS" in the share sheet, which most apps drop. Nothing is drawn on the document itself. The only page stamp is the optional watermark (PBI-028a, `stampWatermark` in `features/vault/data/share_pack.dart`), which is user-chosen and the same on both tiers. | Done (dev) |
| F-04 | 2026-11-12 | Capture / OCR | Does the app shrink images for OCR? (Asked while testing.) | No. Scanned JPEGs are stored byte for byte (re-encoded at quality 90, same size, only when they need rotating or aren't JPEG — `_toJpeg` in `features/capture/data/capture_service.dart`), and ML Kit reads the full-size file (`features/capture/ocr/document_analysis.dart`). The only downscaled copies are internal: 512 px for the blur check, 9×8 for the duplicate hash. | Done (dev) |
| F-05 | 2026-11-12 | Money / Auto Tasks | Adding a one-off bill due later this month (e.g. 20 Nov) is hard to find. | The Money screen's "Add expense" only takes dates up to today (spent money). A future bill has to be added under More → ⚡ Auto Tasks → Add, with How often = Once — nothing on the Money screen points there. A typed task ("Pay … Rs … on 20 Nov") gives a reminder but stays out of the Forecast and the to-pay total. | Done (dev) |
| F-06 | 2026-11-12 | Money / Auto Tasks | A payment marked paid by mistake can't be reversed after the 5-second Undo. | `PaymentService.undo` reverses everything, but only from the 5 s snackbar. After that: the Forecast row shows "Paid" with no action; the expense it logged can't be deleted (`ExpenseService.delete` refuses payment-linked expenses, the button is hidden); the linked task is done and hidden (see F-01). The wrong amount stays in the month's spending. | Done (dev) |

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

## Acceptance Criteria (F-01 to F-06, groomed 2026-11-12)

**F-01 Completed tasks** (design decision D5)
1. Tasks → ⋮ → **Completed tasks** opens a list of done tasks, most recently completed first, grouped by the day they were ticked off, each with its time.
2. **Mark as not done** on a row reopens the task; a repeating task's next occurrence, created by that completion, is removed again (no duplicate).
3. A task that stands for a paid payment asks to **mark the payment unpaid** instead (F-06), so Money and Tasks never disagree.
4. Empty state when nothing is completed. Archived tasks stay out of scope (tasks have no archive; the question stays open below).

**F-02 Money overview, layout A (dense summary)** — Design/design-system.md §4.10
1. Hero card: "Spent this month" (or "Spent in {month}"), the total, a delta chip (arrow + words; warning tint when spending is up, success when down), and with a salary set a progress bar with "Rs X left of Rs Y" (warning above 85%, danger above 100%). With no salary: "Add your income to see what's left".
2. Three stat tiles: per day (whole rupees), biggest category, bills paid of the month's bills. They stay in one row on a 360 dp phone and stack at text above 1.3× or below 300 dp.
3. Spending by category as before (bar + ranked rows).
4. **Coming up** (current month): the next three unpaid bills by due date (overdue in the danger colour), the amount still to pay, **See forecast**, and **Add a bill to pay** (F-05).
5. Expenses grouped by day with a day total; the latest three days, then "See all N expenses".
6. No overflow at text 1.0 and 1.3, light and dark, English and Urdu; tap targets ≥ 48 dp; no new colour, font-size or radius literals.

**F-03 Free-tier share footer with QR**
1. On the free plan, every page of every shared document gets a white strip **added under the page** (the page is never covered) with a QR code at the start side and the line "Shared with LifeOS. Scan to get the free app for Android and iPhone." (EN/UR).
2. Applies to watermarked shares, bundles and the plain "Share file", which on the free plan goes out as one PDF (its subtitle says so). Premium shares carry no footer, and "Share file" sends the stored file as before.
3. With a watermark on, the watermark's own footer band stays on the page and the promo strip sits below it: they never overlap.
4. The QR code is generated on the phone and points to `promoDownloadUrl` (`lib/core/app_links.dart`), a **placeholder until the final release**.

**F-04 Smaller stored pages**
1. A scanned page larger than 2,400 px on its long edge is stored at 2,400 px (shape kept), JPEG quality 85.
2. A page within the limit is stored byte for byte as before; imported PDFs are untouched.
3. OCR is unchanged: it reads the scanner's original file, before this step.

**F-05 One-off bill to pay**
1. **Add a bill to pay** (name, optional amount, due date from today up to a year ahead, reminder on the day / 1 / 3 / 7 days before, optional category) creates one payment and its task, with no Auto Tasks rule and so no free-tier rule limit.
2. Reachable from the Money overview (Coming up), the Forecast tab (and its empty state), and the expense sheet ("Not paid yet? Add it as a bill to pay").
3. The bill shows in the Forecast and the month's "still to pay", and is paid through the usual completion chain.

**F-06 Mark as unpaid**
1. A paid payment offers **Mark as unpaid** — on its Forecast row and on its logged expense (which still can't be deleted directly) — after a confirm dialog with a danger-coloured button.
2. It reverses the whole chain at any time, from the database: payment back to upcoming, its expense removed, its receipt to Trash, its task reopened, an installment counted back (an ended installment rule becomes active again).
3. The payment can be paid again afterwards.

## Dev & QA Notes (2026-11-12)

Code:
- F-06: `PaymentService.markUnpaid` (`features/money/data/payment_service.dart`) and `TaskService.reopen` (`features/tasks/data/task_service.dart`), which finds the occurrence a repeating task's completion created by its exact computed due date. UI: `confirmMarkUnpaid` in `features/money/ui/paid_sheet.dart`, used by the Forecast row, the expense sheet and the Completed list.
- F-05: `PaymentService.addBill`; `features/money/ui/bill_sheet.dart`.
- F-01: `features/tasks/completed_screen.dart`, route `/tasks/completed`, overflow menu on the Tasks app bar; `TaskService.watchCompleted`.
- F-02: `features/money/money_screen.dart` rewritten. New shared `HeroCard` and `CaptionedProgress` (`shared/widgets/hero_card.dart`), `StatTile` and `StatTileRow` (`shared/widgets/stat_tile.dart`), built to §3.4 so the design slices can reuse them. `editSalary` in `forecast_view.dart` is now shared.
- F-03: `PromoFooter` and `stampPromo` in `features/vault/data/share_pack.dart` (strip below the page; QR drawn with the `qr` package, now a direct dependency — it was already in the lock file through `pdf`); `freeTierFooter` in `features/vault/ui/share_flow.dart`. Fixed print colours `Tokens.printPaper`, `printInk`, `printMuted`.
- F-04: `maxPageEdge` and `shrunkPageQuality` in `features/capture/data/capture_service.dart`.

| Item | Result | Evidence |
|---|---|---|
| F-01 | ✅ | `test/features/tasks/completed_screen_test.dart`: empty state; tick off → listed under its day with the time → Mark as not done → back in Today; a paid payment's task asks to mark the payment unpaid. `test/features/money/mark_unpaid_test.dart`: a repeating task's next occurrence is removed, an older copy is not. |
| F-02 | ✅ | `money_screen_test.dart` (day groups and totals, no Coming up in a past month), `bill_and_unpaid_screen_test.dart`, and the PBI-031 layout suite: no overflow at 1.0/1.3 × light/dark × EN/UR, 48 dp targets, gutter alignment. Screenshots on a 360 × 780 dp phone: `Design/screenshots/pbi-038/1_money_light.png`, `2_money_dark.png`, `3_money_urdu.png`. |
| F-03 | ✅ | `test/features/vault/promo_footer_test.dart`: page pixels unchanged down to the last row, strip below, QR at the start side (left in English, right in Urdu), watermark band and strip both present, nothing added on Premium. `share_flow_test.dart`: a free "Share file" sends one PDF named `Document.pdf` and logs the share. `viewer_screen_test.dart`: Premium still sends the files. Sample page: `Design/screenshots/pbi-038/4_share_footer.jpg`. |
| F-04 | ✅ | `test/features/capture/page_size_test.dart`: 3000×4000 → 1800×2400, 4000×3000 → 2400×1800, 1200×1600 kept byte for byte. All 72 capture tests pass. |
| F-05 | ✅ | `bill_and_unpaid_screen_test.dart`: expense sheet → "Not paid yet?" → bill due 20 Nov for Rs 3,500 → in the Forecast with Rs 3,500 remaining; no rule created. |
| F-06 | ✅ | `mark_unpaid_test.dart` (full reversal long after paying, pay again, an unpaid payment left alone, last installment re-opens its rule, a rule-less bill reverses) plus the widget tests from the Forecast row and from the logged expense. |

`flutter analyze`: no issues · full suite `flutter test`: **742/742 passed**.

**Test changes, on purpose:**
- `test/design/flagship_layout_test.dart` AC1: Money no longer has to show six expense rows on the first screen. It now checks that the hero, the stat tiles and Coming up fit on one screen — the density change the design plan's slice 3 anticipated.
- `share_flow_test.dart` and `viewer_screen_test.dart`: a free plain share is now a footer PDF; the "files only" check runs on Premium.

**Not verified / still open:**
- No device pass yet: the Money screen, bill sheet and Completed list on a real phone; the footer on a real share, including **scanning its QR code from a printed page and from a screen**; F-04's real saving on the phone scanner's output (sizes not measured).
- `promoDownloadUrl` is a placeholder (`https://lifeos.example/get`). Replace it with the product site's link before release.
- The share history does not record whether a footer was added (that needs a schema change); the diagnostics log line does.
- Archived tasks (F-01) stay undecided; skipped tasks are not shown in Completed.
- Overlap with the design-system plan: F-01 and F-02 were built here instead of in its slices 5 and 3. Those slices should restyle on top of this work, not rebuild it. The Forecast tab restyle (§4.11) was not part of F-02.
