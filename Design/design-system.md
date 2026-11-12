# LifeOS — Design System and Screen Redesign

**Version:** 1.0 · **Date:** 2026-11-11
**Applies to:** `SourceCode/lifeos_app` (Flutter, Material 3)
**Companions:** `LifeOS-Founders-Pack/lifeos-ui-flow.md` (screen inventory), `PBI/PBI-031-flagship-compact-layout.md` (spacing and density, done), `PBI/PBI-038-testing-feedback.md` (F-02 Money redesign)
**Status:** Approved for development — nothing here is built yet. The owner accepted all nine decisions in Part 6 on 2026-11-11.

## How to read this document

- **Part 1** lists what is wrong today, screen by screen, with file references.
- **Part 2** gives the rules that settle design arguments.
- **Part 3** is the design system: exact values for colour, type, shape, components, charts and motion.
- **Part 4** redraws the main screens using only Part 3's components.
- **Part 5** is the build order.
- **Part 6** records the nine decisions the owner made.

File paths are relative to `SourceCode/lifeos_app/lib/` unless they start with `test/` or `PBI/`. Line numbers were read on 2026-11-11 and will drift.

**What already exists and stays.** PBI-031 put all spacing on a token scale, aligned every screen to one 16 dp gutter, and added tests that keep it so. This document does not change that scale. It adds what is still missing: a type scale, colour roles, shape and elevation rules, a shared component set, defined loading, empty and error states, and motion rules.

---

# Part 1 — Audit

## 1.1 Problems that appear on almost every screen

These are ranked by how much they hurt a first-time user. Fixing them once, in shared code, fixes most screens.

| # | Problem | What the user sees | Where (examples) |
|---|---|---|---|
| A1 | **Loading looks like "empty".** Streams are read with `.value ?? const []`, so while data loads, or when it fails, the screen shows its empty state. | A new user sees "nothing here" or first-run prompts for a moment on every launch. On error, the screen says there is no data. | `features/home/home_screen.dart:33-63`, `features/money/ui/forecast_view.dart:38-39`, `features/atc/atc_rules_screen.dart:52`, `features/vault/vault_list_screen.dart:58`, `features/vault/expiring_screen.dart:19`, `features/score/score_screen.dart:37` |
| A2 | **Error states have no way out.** Errors show a warning emoji and a title, often with an empty message, and never a Retry button. Two screens can spin forever. | A dead end. | `features/tasks/tasks_screen.dart:90-94`, `features/vault/trash_screen.dart:42`, `features/vault/bundle_screen.dart:60-83`, `features/vault/share_history_screen.dart:29` |
| A3 | **Destructive actions follow four different patterns.** Some delete at once with Undo, some confirm with no Undo, some do neither. No confirm button uses the danger colour. | The user cannot predict whether a tap is safe. | Viewer delete: undo only (`features/vault/document_viewer_screen.dart:127-146`). Edit-sheet delete: confirm only (`features/vault/ui/document_sheet.dart:189-211`). Expense delete, pack delete, clear logs, subtask and reminder delete: neither (`features/money/ui/expense_sheet.dart:86-93`, `features/vault/bundle_screen.dart:423-429`, `features/settings/diagnostics_screen.dart:90`, `features/tasks/ui/task_detail_screen.dart:164,316`) |
| A4 | **Key actions are hidden behind gestures.** Snooze is swipe-only. Multi-select is long-press only. Document details open only by dragging a 36 × 4 dp handle. | Features that exist but are never found. | `features/tasks/ui/task_tile.dart:80-92`, `features/vault/vault_list_screen.dart:145`, `features/vault/document_viewer_screen.dart:235-242` |
| A5 | **No clear primary action on many screens.** Task detail has no "Mark done". The populated Money screen and folder lists have no visible add action of their own. The document viewer shows four equal actions. | The user has to hunt for the next step. | `features/tasks/ui/task_detail_screen.dart:336-395`, `features/money/money_screen.dart`, `features/vault/vault_list_screen.dart:119-135`, `features/vault/document_viewer_screen.dart:90-148` |
| A6 | **Text hierarchy is improvised.** Titles use whichever Material default was nearest. Section headers exist in five separate copies with different colours and padding. Only body and label sizes are set in the theme. | Screens feel related but not designed together. | Header copies: `shared/widgets/section_header.dart`, `features/home/home_screen.dart:263`, `features/tasks/tasks_screen.dart:252`, `features/money/money_screen.dart:311`, `features/atc/atc_rules_screen.dart:122` (`_GroupTitle`), plus `VaultSectionTitle` in `features/vault/ui/document_tile.dart:150`. Score uses `titleSmall` instead (`features/score/score_screen.dart`). |
| A7 | **Flat lists on a bare background.** Most content is plain `ListTile` rows with no grouping. Cards appear in some places and not in their siblings (Home's money strip is a card, its score block is not). | Nothing stands out; the screen reads as a settings page. | `features/money/money_screen.dart` (F-02), `features/home/home_screen.dart:221-256`, `features/more/more_screen.dart` |
| A8 | **Urdu and right-to-left defects.** Swipe backgrounds and several alignments use left and right rather than start and end. The score sparkline is drawn left-to-right under labels that mirror. Section headers are upper-cased with letter spacing, which has no meaning in Urdu and can break letter joining. | Misplaced labels and a chart that does not match its axis in Urdu. | `features/tasks/ui/task_tile.dart:78,84`, `features/home/ui/attention_tile.dart:65`, `features/score/ui/sparkline.dart:147`, `features/vault/vault_screen.dart:302` (`Border(left:)`), 19 `toUpperCase()` calls in `lib/` |
| A9 | **Fixed sizes around text.** Strips, bars and columns have fixed heights and widths, so text clips at large font sizes. Classic already forces 1.3×. | Cut-off text for the users Classic was made for. | Vault app-bar bottom 112 dp and expiry strip 92 dp (`features/vault/vault_screen.dart:79,221`), forecast calendar strip 64 × 36 dp (`features/money/ui/forecast_view.dart:215,231`), percent column 52 dp (`features/money/ui/category_breakdown.dart:80`), score labels 92 dp (`features/score/score_screen.dart:145`) |
| A10 | **Colours that fail contrast.** See 1.2. | Amber and green rings, dots and chips that are hard to see. | `core/theme/tokens.dart:10-25` |
| A11 | **Emoji used as system icons at ad-hoc sizes.** 25 raw `TextStyle(fontSize: …)` calls, mostly to size emoji. Emoji look different on every phone brand and carry no label for screen readers. | An inconsistent, informal look next to Material icons. | `features/more/more_screen.dart:30-55`, `features/settings/settings_screen.dart:324`, `shared/widgets/empty_state.dart:44`, `features/tasks/ui/task_actions.dart:62-74` |
| A12 | **No reduce-motion support.** Nothing in `lib/` reads the system's "remove animations" setting. | The score ring always animates. | `features/score/ui/score_ring.dart` |
| A13 | **Unsaved edits can be lost silently.** Task title and notes save only when focus leaves the field; pressing back with the cursor in notes drops the edit. The add-rule sheet discards everything if the free limit is hit on save. | Lost work with no warning. | `features/tasks/ui/task_detail_screen.dart:109,288`, `features/atc/ui/rule_form.dart:132-135` |

## 1.2 Colour contrast, measured

Contrast was calculated with the WCAG formula against white and a typical Material 3 dark surface (`#121318`) and raised dark surface (`#292A30`). Icons, rings and chart marks need 3:1; text needs 4.5:1. The surface values are approximations of what the seed generates; re-run the check against the real scheme in a test (Part 5, slice 0).

| Token | Value | On white | On dark surface | On raised dark | Verdict |
|---|---|---|---|---|---|
| `scoreMid` | `#FFB300` | 1.8 | 10.3 | 8.0 | **Fails in light mode** |
| `scoreHigh` | `#43A047` | 3.3 | 5.6 | 4.3 | Passes for graphics only, narrowly |
| `scoreLow` | `#E53935` | 4.2 | 4.4 | 3.4 | Graphics only |
| People | `#FFA000` | 2.0 | 9.1 | 7.0 | **Fails in light mode** |
| Work | `#1E88E5` | 3.7 | 5.0 | 3.9 | Graphics only in light |
| Mind | `#5C6BC0` | 4.9 | 3.8 | 2.9 | **Fails on raised dark** |
| Money | `#2E7D32` | 5.1 | 3.6 | 2.8 | **Fails on raised dark** |
| Health | `#D32F2F` | 5.0 | 3.7 | 2.9 | **Fails on raised dark** |
| Vault | `#546E7A` | 5.4 | 3.4 | 2.7 | **Fails on raised dark** |

The cause is one fixed value per token for both light and dark. Part 3.1 gives each token a light and a dark value.

## 1.3 Screen-by-screen findings

Only problems beyond the shared ones above are listed.

**Home** (`features/home/home_screen.dart`)
- The score block is a bare row; the page has no focal point.
- "See all" appears only when the attention list is over its cap, so the header changes shape from day to day.
- Marking a payment paid from the attention list is swipe-only when the payment has a task (`features/home/ui/attention_tile.dart:49-85`).
- Urgent and soon are two similar coloured emoji circles; the difference is colour alone.

**Life Score** (`features/score/score_screen.dart`)
- Bottom padding is a literal `120` (:64) rather than the list-end token.
- "Move to today" acts at once with no Undo (:231).
- No message when there is no history yet; the sparkline draws only a baseline.

**Tasks** (`features/tasks/tasks_screen.dart`, `ui/task_tile.dart`)
- The Today / Upcoming / Domains switch sits in the title bar and scrolls sideways, so a segment can be off-screen.
- The check circle's visual box is 40 dp (:109); the tap area must be confirmed as 48 dp.
- In compact looks the life area is a colour dot only.
- No way to see completed tasks (F-01).

**Task detail** (`features/tasks/ui/task_detail_screen.dart`)
- No Complete and no Snooze. A task can only be finished from a list.
- One long column of about nine ungrouped blocks, with three different text-field styles on one screen.
- The delete confirmation's button is not danger-styled (:381).

**New task sheet and voice** (`features/tasks/ui/new_task_sheet.dart`, `ui/quick_parse.dart`)
- Choosing a date by hand hides all parsed chips, including priority and amount (:196).
- Cancelling the time picker clears a time already chosen (:252-255).
- The mic button closes the sheet and discards typed text (:179).
- Voice capture skips the Overload Shield and offers no way to correct the recognised text.

**Vault home** (`features/vault/vault_screen.dart`)
- The app bar holds four actions (Scan, import, packs, trash) and a 112 dp bottom area with search and five filter controls.
- A vault with no documents shows empty People and Folders sections rather than an invitation to scan.
- The expiry card is hand-built with its own amber `#B26A00` (:288), repeated in `features/vault/expiring_screen.dart:44`.
- Marking a favourite takes three steps: open, Edit, star.

**Folder and person lists** (`features/vault/vault_list_screen.dart`)
- The "Remove person" dialog's button says Delete (:249-253).
- Selection mode offers one action only (share as PDF).

**Document viewer** (`features/vault/document_viewer_screen.dart`)
- Details sit in a panel that opens at 12% height and can only be dragged.
- Editing is split in two: type, fields and dates in the panel; title, tags, folder and person in a separate Edit sheet. "Edit" and "Move" open the same sheet.
- The four bottom actions are custom widgets with no button semantics and no disabled look (:170-189).
- The loading state has no app bar, so no back button (:66).
- A failed image shows only a broken-image icon (`features/vault/ui/document_pages.dart:197`).

**Scan review** (`features/capture/review_screen.dart`)
- About eleven controls for a bill, with Save at the end of the scroll rather than pinned.
- The document type appears twice in one row, as a chip and a dropdown (:1005-1043).
- Scan-another and import appear twice, in the app bar and at the bottom.
- The duplicate warning is coloured text only.
- This breaks the "under 15 seconds" target in the UI flow document.

**Bundles and sharing** (`features/vault/bundle_screen.dart`, `ui/share_flow.dart`)
- A load failure leaves a spinner forever.
- A watermarked share takes four taps plus typing.
- The watermark dialog's fields use a different border style from the rest of the app.

**Money overview** (`features/money/money_screen.dart`) — see F-02 in PBI-038
- Plain total, an 8 dp bar, then two flat lists. No cards, no salary context, no upcoming bills.

**Forecast** (`features/money/ui/forecast_view.dart`)
- Calendar strip: due days are a dot only, today is a border only, cells cannot be tapped and have no screen-reader text.
- The `~` before estimated amounts is not explained (:273).
- The salary dialog has no validation; an empty amount silently clears the salary.

**Expense and paid sheets** (`features/money/ui/expense_sheet.dart`, `ui/paid_sheet.dart`)
- The amount field has no label.
- If saving fails, the Save button stays disabled (:61-84).
- On the paid sheet the filled (primary) button is labelled **Skip** (:180). Three buttons share one row and will truncate in Urdu.

**Auto Tasks (ATC)** (`features/atc/`)
- The add-rule sheet shows seven to ten groups and about 25 chips at once.
- Rule detail mixes instant-apply (the switch) and Save-to-apply (the fields) with no unsaved-changes guard.
- Rule detail's loading state has no app bar (`rule_detail_screen.dart:39`).

**More, Settings, Profile** (`features/more/`, `features/settings/`, `features/profile/`)
- More is four bare rows. Premium and AI are at the bottom of Settings, the least-visited place in the app.
- Settings is one flat list: 8 groups, about 21 rows. Rows differ in anatomy: some have icons, some emoji, some none; some navigating rows have chevrons, some do not.
- Language is in both Settings and Profile. Trash is in both More and Settings.
- "Delete all data" sits directly under Diagnostics with only its icon in red.
- There is no text-size control, although a `textScale` column exists in the database.
- Look choices have a name only: no description, no preview.

**Onboarding** (`features/onboarding/onboarding_screen.dart`)
- No progress indicator and no Back (:128). Every step is titled "Welcome".
- On the payments step, a tonal "Turn on" inside each card competes with the filled "Next"; pressing Next discards a half-filled form.
- The notification permission prompt fires by itself on the last step (:420).

**Premium** (`features/premium/ui/premium_screen.dart`)
- Two benefits, a price, Subscribe and Restore. No busy indicator while buying, no success confirmation, no cancel-anytime or terms and privacy text.

**AI settings** (`features/ai/ui/ai_settings_screen.dart`)
- The advanced form is always open. Save gives no feedback. "Use managed" wipes the stored key without asking (:181).

**App lock** (`features/security/lock_gate.dart`)
- A fingerprint icon is shown even for PIN or face unlock. No message after a failed attempt.

---

# Part 2 — Design principles

1. **One hero, one primary action.** Each screen has one thing the eye lands on first and at most one filled button. Everything else is quieter.
2. **Numbers are the hero on money and score screens.** The amount or score is the largest text. Labels are small and grey. Figures are right-aligned in tabular numerals.
3. **Every action is visible.** Swipe and long-press are shortcuts for people who know them. Every action they perform is also reachable by a visible button or menu.
4. **Safe by default.** Anything that can be undone happens at once and offers Undo. Anything that cannot asks first, with a red button that names the action. Never both, never neither.
5. **Calm, not decorated.** No gradients and no shadows on cards. Colour marks meaning (urgent, paid, a life area) and is always paired with an icon or words.
6. **One system, three looks.** Flagship, Funky and Classic differ only in token values: density, text size, corner radius and seed colour. No screen has look-specific layout code.
7. **Loading, empty and error are designed, not left over.** Every screen that reads data shows a skeleton while loading, an invitation when empty, and a reason with Retry on error.

---

# Part 3 — Design system

All values go into `core/theme/tokens.dart` and `core/theme/app_theme.dart`. Feature code must not contain colour, size, radius or duration literals; `test/design/flagship_layout_test.dart` (AC5) already enforces this for padding and is extended in slice 0 to cover the rest.

## 3.1 Colour

### Base scheme
Keep `ColorScheme.fromSeed` with the existing seeds (`#5C6BC0` for Flagship and Classic, `#E91E63` for Funky). Screens use scheme roles, never hex values.

### Surfaces and elevation
The app is flat. Depth comes from three surface tones, not shadows.

| Level | Role | Used for |
|---|---|---|
| 0 | `surface` | Page background, app bar, bottom bar |
| 1 | `surfaceContainerLow` | Cards, stat tiles, grouped list blocks |
| 2 | `surfaceContainerHigh` | Bottom sheets, dialogs, menus |
| Tint | `primaryContainer` with `onPrimaryContainer` text | The hero card only, one per screen |

- Cards have elevation 0 and no border.
- A 1 dp `outlineVariant` border is used only on text fields and on selectable cards (role picker, look picker). A selected card gets a 2 dp `primary` border and a check icon.
- Only the floating add button and snackbars keep a shadow.
- Dividers: `outlineVariant`, 1 dp, between rows inside a list block. Not between cards, and not under section headers.

### Semantic colours
Add a `ThemeExtension<AppColors>` with these roles. All pairs meet 4.5:1 (measured: light text on its container 5.3–5.4, on white 6.3–6.5; dark text on its container 9.0–9.9).

| Role | Light: text / icon | Light: container | Dark: text / icon | Dark: container | Dark: text on container |
|---|---|---|---|---|---|
| success | `#1B6E3A` | `#DDF3E4` | `#7FD69B` | `#0F3D22` | `#BFEFCB` |
| warning | `#8A5300` | `#FFE9C7` | `#F2BE6B` | `#4A3000` | `#FFDFA8` |
| danger | `#B3261E` | `#FCE4E2` | `#F2B8B5` | `#5C1A16` | `#FAD9D7` |
| info | `#1E5FA8` | `#DCEBFB` | `#9CC7F5` | `#0E3A63` | `#CFE4FB` |

In light mode, text on a container uses the role's text colour. A filled danger button is the text colour as background with white text (6.5:1).

Meaning, fixed across the app:
- **danger** — overdue, expired, failed, destructive actions.
- **warning** — due soon, expiring within 30 days, needs attention. This replaces the two copies of `#B26A00`.
- **success** — paid, done, renewed, on track.
- **info** — neutral notices, estimates, tips.

### Life Score colours
Replace the three single values with light and dark pairs. Thresholds do not change.

| Band | Light | Dark | Contrast on page (light / dark) |
|---|---|---|---|
| Low (< 40) | `#C62828` | `#EF6C6A` | 5.6 / 6.2 |
| Mid (40–69) | `#B26A00` | `#F2B441` | 4.2 / 10.1 |
| High (≥ 70) | `#2E7D32` | `#66BB6A` | 5.1 / 7.9 |

These are for the ring and bars. Score text beside the ring uses `onSurface`; the band is also named in words ("Good", "Needs care") so colour is never the only signal.

### Life-area accents
Light and dark values per area. Use for dots, chip backgrounds at 16% opacity with `onSurface` text, and leading icons. Never as a page or card fill.

| Area | Light | Dark |
|---|---|---|
| Mind | `#5C6BC0` | `#9FA8DA` |
| Money | `#2E7D32` | `#81C784` |
| Health | `#D32F2F` | `#EF9A9A` |
| People | `#9A5B00` (was `#FFA000`) | `#FFCC80` |
| Work | `#1565C0` (was `#1E88E5`) | `#90CAF9` |
| Soul | `#00796B` (was `#00897B`) | `#80CBC4` |
| Vault | `#546E7A` | `#B0BEC5` |

All light values are at least 4.5:1 on white; all dark values are at least 6:1 on the raised dark surface.

### Spending category palette
Keep the validated palette in `features/money/ui/category_colors.dart` unchanged, but move it into the token layer (`core/theme/`), next to the other colours. Its rule stays: every swatch is shown with a name and an amount.

## 3.2 Typography

### Fonts
Bundle two free (Open Font License) font families as assets. No font is downloaded at run time.

- **Inter** for Latin text and all numerals, in weights 400, 500 and 600.
- **Noto Naskh Arabic** for Urdu, in weights 400, 500 and 600, set as the fallback family so Urdu text picks it up automatically.

Why: the app then looks the same on every Android brand and on iOS, tabular numerals are guaranteed, and widget tests can render Urdu (today they show boxes, per PBI-031's notes). Cost: about 1 MB of app size.

Why Naskh and not Nastaliq: Nastaliq is the traditional Urdu style, but its tall, sloping lines do not fit 48 dp rows and chips. (Decided, D1.)

### Scale
Sizes are in sp. "Compact" is Flagship and Funky; "Roomy" is Classic. Body, secondary and label sizes are the existing PBI-031 values and do not change, so its tests keep passing.

| Style (Material slot) | Use | Compact size / line | Roomy size / line | Weight |
|---|---|---|---|---|
| `displaySmall` | Hero number: month total, score | 28 / 34 | 32 / 40 | 600 |
| `headlineSmall` | Editable title on a detail screen; onboarding headline | 22 / 28 | 24 / 32 | 600 |
| `titleLarge` | App bar title, sheet and dialog title | 20 / 26 | 22 / 28 | 600 |
| `titleMedium` | Card title, stat-tile value, emphasised row | 16 / 22 | 18 / 24 | 600 |
| `titleSmall` | Section header | 13 / 18 | 14 / 20 | 600 |
| `bodyLarge`, `bodyMedium` | Row titles, paragraphs, field text | 15 / 22 | 16 / 24 | 400 |
| `bodySmall` | Row subtitles, helper text | 13 / 18 | 14 / 20 | 400 |
| `labelLarge` | Button text | 14 / 20 | 15 / 20 | 600 |
| `labelMedium` | Trailing values: amounts, times, counts | 13 / 18 | 14 / 20 | 500, tabular |
| `labelSmall` | Chips, bottom-bar labels, badges | 12 / 16 | 12 / 16 | 500 |

Rules:
- Only three weights: 400, 500, 600. Replace every `w700`.
- Amounts and times always use tabular numerals: `labelMedium`, `titleMedium` in stat tiles, and `displaySmall`.
- Secondary text is `onSurfaceVariant`. Never lower the opacity of text.
- **Section headers are sentence case, `titleSmall`, `onSurfaceVariant`, no letter spacing.** This replaces the upper-case, letter-spaced headers. Reason: Urdu has no capitals and letter spacing can break its joined letters. This reverses PBI-031's "small caps" wording. (Decided, D2.)
- Letter spacing is 0 on every style, in every language. Inter is drawn for zero tracking at text sizes (Material's defaults were tuned for Roboto and looked loose in the slice 0 review), and spacing can break Urdu's joined letters.
- Urdu: line height is multiplied by 1.2. Apply this once in the theme, by locale.
- No style below 12 sp.
- No raw `TextStyle(fontSize: …)` in feature code. A test scans for it.

### Icons and emoji
- Icon sizes: 16 (inline with text), 20 (inside chips and buttons), 24 (rows, app bar). Tokens: `iconS`, `iconM`, `iconL`.
- System interface uses Material outlined icons: navigation, row icons, empty states, the quick-add menu, More and Settings rows.
- Emoji are for content the user chose: a person's avatar, a folder's symbol, the profile picture, spending category symbols. Sizes come from tokens: `emojiS` 20, `emojiM` 24, `emojiL` 40.
- Chevrons and arrows that mean "forward" or "back" must mirror in Urdu. Use icons that auto-mirror, and test it.

## 3.3 Spacing, shape and layout

**Spacing.** Unchanged from PBI-031: 4 / 8 / 12 / 16 / 24 dp compact, 4 / 8 / 16 / 24 / 32 dp roomy, 16 dp gutter.

**Radius scale.** New tokens replacing the scattered 2, 3, 4, 6, 8 and 12 literals.

| Token | Flagship, Classic | Funky | Used for |
|---|---|---|---|
| `radiusXs` | 4 | 6 | Bars, swatches, progress tracks |
| `radiusS` | 8 | 12 | Thumbnails, calendar cells, small tiles |
| `radiusM` | 12 | 20 | Cards, stat tiles, text fields, list blocks |
| `radiusL` | 16 | 24 | Hero card, bottom sheets, dialogs |
| `radiusFull` | 999 | 999 | Chips, pills, search field, avatars |

`Tokens.radius` (16) becomes an alias for `radiusL`.

**Card or no card.**
- Hero and summary content: card.
- A group of settings or details rows: one list block (a card holding rows with dividers).
- A long, scrolling list of the same kind of item (tasks, expenses, documents): plain rows on the page, under a section header. No card per row.
- Space, not a line, separates sections: `spaceL` above a section header, `spaceXs` below it.

**Sizes that hold text must grow.** No fixed height on anything containing text. Use minimum heights and let content wrap. Horizontal strips of cards use an intrinsic height or wrap to a second row at large text sizes.

**Target sizes.** Layout must hold at 360 dp width, and at text scale 1.0, 1.3 and 2.0. PBI-031 tested up to 1.3. Scale 2.0 is enforced on the five tab screens, sheets and dialogs, and is best effort elsewhere (decided, D3).

## 3.4 Components

Each component lives in `shared/widgets/`. Names are suggestions; existing widgets are extended, not duplicated.

### Screen scaffold — `TabScaffold` (extend)
- App bar: `titleLarge` title at the start; at most **two** icon actions, then an overflow menu.
- Optional slot under the app bar for a search field or segmented switch. It sizes to its content.
- Body, then optional pinned bottom action bar.
- Do: put the third and later actions in the overflow menu. Don't: put a filled button in the app bar.

### Async body — `AsyncBody` (new)
Wraps any `AsyncValue` and renders the right state. This removes every `.value ?? const []`.
- **Loading:** a skeleton that matches the screen (see Skeleton). Shown only after 150 ms to avoid a flash.
- **Error:** `StateMessage.error` with a Retry button that invalidates the provider.
- **Empty:** `StateMessage.empty` supplied by the screen.
- **Data:** the screen's builder.

### State message — `EmptyState` (extend, keep the name)
- Anatomy: a 56 dp circle in `surfaceContainerLow` holding a 24 dp outlined icon; `titleMedium` title; `bodyMedium` grey message of one or two lines; at most one button.
- Variants: `empty` (filled button that starts the first item), `error` (danger-tinted circle, tonal Retry button, message says what failed in plain words), `done` (success-tinted circle, no button, for "nothing needs attention").
- Keep the `inList` option. Replace the `emoji` parameter with `icon`.
- Do: name the space and invite ("Scan your first document"). Don't: apologise ("Nothing here yet") or show a raw error string.

### Skeleton (new)
Grey rounded blocks in `surfaceContainerLow` in the shape of the content: one hero block, three stat blocks, five row blocks. Static when reduce-motion is on; otherwise a slow 1.2 s opacity pulse.

### Section header — `SectionHeader` (extend; delete the other five copies)
- Anatomy: `titleSmall` title · optional count in grey ("Today · 5") · optional trailing text action ("See all").
- On the gutter; `spaceL` above, `spaceXs` below. Marked as a heading for screen readers.
- Tones: default (`onSurfaceVariant`) and danger (with a warning icon, for Overdue).
- Wraps to two lines instead of truncating. The trailing action keeps a 48 dp tap area.

### Hero card (new)
- Tint surface, `radiusL`, padding `spaceL`.
- Anatomy: small label · hero value in `displaySmall` · optional delta chip · optional progress bar with a caption · or a leading ring with two lines of text.
- One per screen, always first.

### Stat tile (new)
- Level 1 surface, `radiusM`, padding `spaceM`.
- Anatomy: `labelSmall` grey label above a `titleMedium` tabular value. Optional 16 dp leading icon.
- Used in a row of two or three, equal width, `spaceS` apart. At text scale above 1.3, or below 340 dp content width, the row becomes a column.

### List block (new)
A level 1 card with `radiusM` that holds rows separated by inset dividers. For Settings, More, Profile, and detail fields.

### List row (theme plus conventions)
- Leading column, 24 dp: icon, avatar, check circle or colour dot. One kind per list.
- Title `bodyLarge`, one line, then ellipsis. Optional subtitle `bodySmall`, one line.
- Trailing column: a value in `labelMedium`, **or** a status chip, **or** one control (switch, chevron, icon button). Not two.
- A row that navigates always shows a chevron. A row that opens a picker shows its current value and a small edit affordance.
- Heights stay as PBI-031: 48 / 56 dp compact, 56 / 64 dp roomy, as minimums.

### Chips
| Kind | Look | Use |
|---|---|---|
| Status | Semantic container, 16 dp icon + label, not tappable | Overdue, Due soon, Paid, Estimated |
| Filter / choice | Material `FilterChip` / `ChoiceChip`, outlined; selected is filled with a check | Filters, category, priority |
| Area | Area accent at 16% + area name, `onSurface` text | Life area on tasks |
| Delta | Arrow icon + "6% vs October" | Change against a previous period |

A status chip always has an icon and words. A delta chip uses an up or down arrow and words; it is neutral grey unless the change is clearly good or bad for the user.

### Buttons
| Level | Widget | Use | Per view |
|---|---|---|---|
| Primary | `FilledButton` | The one main action | At most one |
| Secondary | `FilledButton.tonal` | A strong alternative; row-level actions such as Pay or Renew | Any |
| Tertiary | `OutlinedButton` | Neutral alternatives beside a primary | Any |
| Text | `TextButton` | Low-emphasis: Cancel, See all, Skip | Any |
| Destructive | `FilledButton` in danger colour (confirm dialogs only); `TextButton` in danger colour elsewhere | Delete, Remove, Clear | — |

- Minimum height 48 dp. Labels are a verb first, one to three words.
- A primary button on a form or flow is **pinned** in a bottom action bar, full width, above the keyboard.
- A busy button shows a 16 dp spinner in place of its icon and stays the same width. It re-enables if the action fails.
- Avoid disabled buttons. If Save needs something, keep it enabled and show what is missing on press, next to the field.

### Bottom action bar (new)
Pinned to the bottom, level 0 surface with a top divider, padding `spaceM` and the gutter, respects the safe area and keyboard. Holds one primary button, optionally with one text or outlined button before it.

### Icon action bar (new, for the document viewer)
Up to four labelled icon buttons of equal width, each a real button with a tooltip and a disabled style. A fifth and later go into "More".

### Bottom sheet — `SheetFrame` (extend `_SheetFrame` in `features/vault/ui/vault_sheets.dart` and share it)
- Drag handle (already themed), `titleLarge` title at the start, close icon button at the end.
- Content scrolls; the primary button is pinned in the sheet's bottom action bar.
- Padding: the gutter on both sides, `spaceL` under the title.
- Sheets are for creating and quick edits. Dialogs are for confirmations and short choices only.

### Dialogs
- Confirmation: title is the question ("Delete this rule?"), body is one sentence on the consequence, buttons are Cancel (text) and the action by name (danger filled). Never "OK" or "Yes".
- Choice: up to three options, one filled.

### Destructive action pattern
One rule for the whole app.

| Kind | Examples | Behaviour |
|---|---|---|
| **Reversible** | Complete or snooze a task, move a document to trash, archive, remove a row from a bundle, delete a subtask or reminder, delete an expense, clear a filter | Do it at once. Show a snackbar naming what happened, with **Undo**, for 5 seconds. |
| **Irreversible** | Delete forever from trash, delete all data, delete a rule and its history, clear diagnostics log, remove a stored AI key | Confirmation dialog with a danger-coloured button that names the action. No snackbar. |

If an action listed as reversible cannot be undone with the current services, it moves to the irreversible row until it can. Report those cases rather than faking an Undo.

### Snackbar
One line, optional single action. Floating, above the bottom bar and the add button. Used for confirmations of completed actions and Undo. Not for errors that need a decision.

### Text fields
- One style everywhere: outlined, `radiusM`, with a visible label above the border. No borderless or underlined fields, except the large editable title on task and document detail, which keeps a pencil affordance.
- Helper or error text below, in `bodySmall`. Errors say how to fix it.
- Amount fields: decimal keyboard, currency prefix, tabular numerals, right-aligned in left-to-right languages.
- Forms with more than five controls use progressive disclosure: the essentials first, the rest under "More options".
- Autosaving screens show a small "Saved" tick beside the title for 2 seconds after each save, and save on back.

### Swipe actions
- Kept as shortcuts on task and attention rows. Backgrounds use start and end alignment, a semantic container colour, and an icon with a label.
- Every swipe action is also in the row's visible control or its overflow menu.

### Floating add button and quick-add menu
- Position and behaviour unchanged (**no navigation change**).
- The four menu items use icons, not emoji, and are listed nearest-first: Task, Scan, Expense, Voice.
- The scrim covers the whole screen, including the bottom bar, and the menu is announced as a menu to screen readers.

## 3.5 Charts and data marks

Charts are drawn with `CustomPainter`, as today. No chart package.

| Mark | Spec |
|---|---|
| **Score ring** | Stroke is 10% of diameter, round caps. Track `surfaceContainerHigh`; arc in the band colour. Number in the centre in `onSurface`. Sizes: 72 dp in the hero, 160 dp on the score screen. The number scales with the ring, not with system text size, and the band is named in text beside it. |
| **Progress bar** | 6 dp tall, `radiusXs`, track `surfaceContainerHigh`, fill `primary`. Turns warning above 85% and danger above 100% of the limit, with a caption stating the figures ("Rs 65,800 left of Rs 150,000"). |
| **Stacked category bar** | 10 dp tall, `radiusXs`, 2 dp gaps between segments. Segments below 3% merge into "Other". A wrapping legend below: swatch, name, percent. |
| **Proportional row bar** | For the full category list: each row has a 4 dp bar under the name, sized to its share. |
| **Sparkline** | 2 dp line in `primary`, 4 dp dots, the last point 6 dp. Day labels below. Mirrors in Urdu: oldest at the start side. |
| **Day-load bar chart and heat cells** | Bars 12 dp wide, `radiusXs`. Over-capacity days use danger with a "Full" label. Cells are tappable and jump to that day. |
| **Calendar strip** | Cells at least 40 × 56 dp, growing with text. A due day shows a dot **and** the count; today is filled tonal with the word "Today" for screen readers. Tapping a cell scrolls the list to that day. |

Rules for all charts:
- Every chart has a one-sentence screen-reader summary with the actual figures.
- No meaning by colour alone: a legend, label or icon accompanies every colour.
- Charts follow text direction.
- A chart with no data shows a short grey sentence in its place, not an empty frame.

## 3.6 Motion

| Token | Value | Use |
|---|---|---|
| `motionFast` | 100 ms | Press feedback, chip select, fade |
| `motionBase` | 200 ms | Check-off tick, sheet content changes, expand and collapse |
| `motionSlow` | 300 ms | Cross-fade between loading and content |
| `motionRing` | 600 ms | Score ring fill |

- Curve: ease-out for things appearing, ease-in for things leaving. Material's own transitions for pages, sheets and dialogs are left as they are.
- Three signature animations only, as the UI flow document says: the check-off tick, the score ring fill, and the scan auto-crop snap. Nothing else animates beyond Material defaults.
- No animated numbers, no bouncing, no confetti. The onboarding finish uses a still success state. This replaces the "confetti-lite" in the UI flow document (decided, D4).
- When the system's reduce-motion setting is on (`MediaQuery.disableAnimations`), every custom animation jumps to its end state and the skeleton does not pulse.

## 3.7 Accessibility and language checklist

Every screen must pass these before it is called done.

- Tap areas at least 48 × 48 dp.
- Text contrast 4.5:1; icons and chart marks 3:1; in light and dark, in all three looks.
- No meaning by colour alone.
- Every icon-only button has a tooltip. Every custom-painted widget has a screen-reader label.
- Section headers are marked as headings.
- No clipping or overflow at 360 dp width, text scale 1.0 and 1.3 (and 2.0 per D3), English and Urdu.
- Mirrors correctly in Urdu: start and end only, never left and right; directional icons flip; charts follow direction.
- No upper-casing and no letter spacing on translated text.
- All text comes from the localisation files, in English and Urdu.

---

# Part 4 — Screen redesigns

Wireframes read top to bottom. Component names refer to 3.4 and 3.5. Sample figures are illustrative.

## 4.1 Home

```
App bar     "Salam, Owais" (titleLarge) / date (bodySmall)        [bell] [profile]
Hero card   [Score ring 72]  Life Score · "Good"
                             "Up 3 since last week"
                             "2 things need attention  >"
Section     Needs attention · 2                          See all
Rows        [warning icon] Electricity bill              Rs 4,850  [Pay]
                           Due tomorrow
            [warning icon] Passport (Ali)                          [Renew]
                           Expires in 28 days
Section     Today · 5                                    See all
Rows        ( ) Pay school fee                           Rs 12,000
                Auto-created
            ( ) Call electrician                         4:00 PM
            ( ) Review CV                                Anytime
Stat tile   [wallet] Payments this week                  Rs 14,500   >
                                                        (+) floating add
```

- **Hero:** the score card. Tapping it opens the score screen.
- **Primary action:** the floating add button. Row-level Pay and Renew are tonal buttons.
- **Changes:** attention rows get a visible action; "See all" is always present; overdue and soon use the danger and warning icons, not two emoji circles; the money strip becomes a full-width stat tile.
- **Loading:** skeleton of one hero block and six rows.
- **Empty (new user):** the hero shows the ring at its start value with "Let's set up your life", then three list-block rows with icons: Scan your first document, Add a monthly payment, Add a task.
- **Empty (nothing due):** `StateMessage.done` in the attention section: "Nothing needs your attention".
- **Error:** `StateMessage.error` with Retry in place of the sections; the app bar stays.

## 4.2 Life Score

```
App bar     Life Score
Hero        [Score ring 160]  "78 · Good"   delta chip "Up 3 this week"
Section     Last 7 days
            Sparkline with day labels
Section     What's in it
List block  Tasks       [progress bar]  24 of 30
            Payments    [progress bar]  25 of 25
            Documents   [progress bar]   9 of 15
Section     Pulling your score down · 2
Rows        Passport (Ali) expires in 28 days            [Set reminder]
            3 tasks overdue                              [Move to today]
```

- One-tap fixes show a snackbar with Undo.
- **Empty history:** "Your trend appears after a few days of use" in place of the sparkline.
- **Nothing pulling it down:** `StateMessage.done`.

## 4.3 Tasks

```
App bar     Tasks                                         [overflow: Completed]
Slot        [ Today | Upcoming | Areas ]   (full-width segmented switch)
Stat tile   Planned today      [progress bar]            4.5h of 6h
Section     Overdue · 1  (danger tone)
Rows        ( ) Renew car token            [chip: 2 days late]
Section     Timed
Rows        ( ) Call electrician                          4:00 PM
Section     Payments
Rows        ( ) Pay school fee                            Rs 12,000
                Auto-created · due Friday
Section     Anytime
Rows        ( ) Review CV                  [area chip: Work]
```

- **Primary action:** the floating add button.
- **Changes:** the switch moves out of the title into the slot under the app bar, full width, so no segment is ever off-screen (this gives back the 48 dp band PBI-031 saved; the load tile makes that space earn its place). Swipe stays as a shortcut, and Snooze is also a visible button on the task detail screen (4.4). The life area is a named chip on a second line when the row has room, a dot plus screen-reader label otherwise.
- **Completed tasks:** reachable from the overflow menu, most recent first, each with "Mark as not done". This is F-01 in PBI-038. (Decided, D5.)
- **Loading:** skeleton rows. **Empty:** "Plan your day" with an Add task button. **Error:** Retry.

## 4.4 Task detail

```
App bar     (back)                                        [overflow: Delete, Skip this cycle, Mute rule]
Title       Pay school fee  [pencil]      "Saved" tick appears after edits
Chip row    [area chip: Money] [status chip: Due Friday]
List block  When        Friday 14 Nov · 9:00 AM           >
            Reminders   1 day before                      >
            Priority    [ Low | Normal | High ]
            Repeats     Monthly                           >
            Person      Ali                               >
List block  Created from  K-Electric bill, scanned 12 Oct >
Section     Notes
            [text field]
Section     Subtasks · 1 of 3
            [x] Collect fee slip
            [ ] ...           + Add subtask
Bottom bar  [Snooze]                      [ Mark done ]
```

- **Primary action:** Mark done, pinned. Snooze is the outlined button beside it.
- **Changes:** fields are grouped into list blocks; one text-field style; destructive and rare actions move to the overflow menu; edits save on back.

## 4.5 New task sheet and voice

```
Sheet       New task                                      [x]
            [ What do you need to do?            ] [mic]
            Parsed: [Fri 5:00 PM x] [Rs 4,850 x] [Money x]
            When:   [Today] [Tomorrow] [Pick date] [Add time]
            More options  v
Bottom bar                                 [ Add task ]
```

- Parsed chips stay visible when a date is picked by hand; a hand-picked value replaces only the matching chip.
- Cancelling a picker changes nothing.
- The mic keeps what was typed and appends the spoken words.
- Voice capture ends on the same sheet, pre-filled, so the text can be corrected and the Overload Shield still applies.

## 4.6 Vault home

```
App bar     Vault                                         [packs] [overflow: Import file, Trash]
Slot        [ Search documents            ] [filter icon with count badge]
Section     People
            (All) (Ayesha) (Ali) (Ammi) (+ Add)           avatars with names, wraps or scrolls
Section     Expiring soon · 2                             See all
            [warning card: Passport · Ali · 28 days left] [card: Visa · Me · 90 days left]
Section     Folders
List        [icon] Identity                               12  >
            [icon] Education                               8  >
            ...
            + New folder
Bottom bar  [ Scan document ]
```

- **Primary action:** Scan document, pinned and full width. It leaves the app bar.
- **Changes:** the app bar drops to two actions; the five filter controls collapse into one filter button that opens a sheet, with active filters shown as removable chips under the search field; expiry cards use the warning and neutral containers with an icon and "28 days left" in words; card height follows its text.
- **Empty vault:** `StateMessage.empty` — "Keep your documents safe" with a Scan document button. People and Folders appear once there is a document.
- **Loading:** skeleton. **Error:** Retry.

## 4.7 Folder and person lists

- Document rows keep the thumbnail, title and one metadata line.
- A "Select" item in the overflow menu starts multi-select; long-press remains a shortcut. The selection bar offers Share, Move and Delete, each labelled.
- The star is tappable on each row.
- The floating add button's Scan saves into the open folder.
- Removing a person or folder says "Remove", not "Delete", and explains what happens to the documents.

## 4.8 Document viewer

```
App bar     Passport — Ali          [star]  [overflow: Move, Archive, Share history, Delete]
Body        Document pages, full width, pinch to zoom
            Page dots · "2 of 3"
Summary     [status chip: Expires in 28 days]   Details  ^      (tappable bar, opens the panel)
Icon bar    [Share]  [Details]  [Renew]  [More]
```

Details panel (opens to 60% on tap; can still be dragged):

```
            Details                                        [x]
List block  Title, Type, Document number, Issue date, Expiry date   (all editable here)
List block  Folder   Identity   >        Person   Ali   >
            Tags     [id] [travel]  + Add
Section     Reminders: 90, 30 and 7 days before expiry
Section     Linked tasks
```

- **Primary action:** Share.
- **Changes:** all editing is in one place, the Details panel; the separate Edit sheet is removed; the panel opens by tapping a labelled button; delete moves the document to trash with Undo (one pattern); archive shows a snackbar with Undo.
- **Loading:** app bar with back button, plus a page-shaped skeleton.
- **Page failed to open:** `StateMessage.error` — "This page couldn't be opened" with Retry.

## 4.9 Scan review

```
App bar     Review scan                                    [overflow: Scan another, Import]
            Page strip (thumbnails, + Add page)
Hero card   "Electricity bill"  [Change]
            Rs 4,850 · due 14 Nov                          (the fields that were read)
            [warning chip: Looks like a duplicate — View]  (only when relevant)
List block  Name       K-Electric — November               >
            Person     Me                                  >
            Folder     Bills and receipts                  >
            More details  v      (remaining extracted fields, file format)
Switch      Create payment task for 14 Nov                 [on]
Bottom bar  [Discard]                      [ Save to Vault ]
```

- **Primary action:** Save to Vault, pinned.
- **Changes:** the type is shown once, with a Change button; what the app read is summarised as a sentence in the hero card, and only uncertain or missing fields are opened for editing; scan-another and import appear once, in the overflow menu. Target: save a correctly read bill in two taps.
- **Batch:** each draft is a card with a status chip and its own Discard; "Save 3 ready" is pinned.

## 4.10 Money overview (F-02, direction A)

```
App bar     Money                                          [< November >]
Slot        [ Overview | Forecast ]
Hero card   Spent this month                               delta chip "6% vs October"
            Rs 84,200
            [progress bar]  "Rs 65,800 left of Rs 150,000 salary"
Stat tiles  [Daily average  Rs 7,655] [Biggest  Bills] [Bills paid  4 of 7]
Section     By category                                    See all
            Stacked category bar + legend
Section     Coming up                                      Forecast
Row         [calendar icon] Electricity bill               Rs 4,850
                            Tomorrow · 3 bills still to pay
Section     Today                                          Rs 3,650
Rows        [dot] Groceries, Imtiaz                        Rs 2,900
            [dot] Fuel                                     Rs 750
Section     Yesterday                                      Rs 12,000
Rows        [dot] School fee                               Rs 12,000
```

- **Hero:** the month total.
- **Primary action:** the floating add button (Expense).
- With no salary set, the progress bar is replaced by a text button "Add your salary to see what's left".
- Tapping a legend entry or "See all" opens the full category list with proportional row bars; tapping a category filters the expense list, with a removable chip.
- The expense list shows the latest three days, then "See all expenses".
- At large text sizes the three stat tiles stack.
- **Loading:** hero, three tiles, five rows as skeleton. **Empty month:** hero shows Rs 0 and the list is replaced by "Log your first expense" with a button. **Error:** Retry.

## 4.11 Forecast

```
Hero card   To pay in November
            Rs 61,500
            [progress bar]  "Rs 23,000 paid · Rs 38,500 left"
            "41% of your salary goes to fixed payments"    (only when a salary is set)
Calendar strip   tappable days, count on due days, today filled
Section     Overdue · 1  (danger tone)
Rows        Internet bill      [chip: 2 days late]         Rs 3,200  [Mark paid]
Section     Upcoming · 3
Rows        Electricity bill   Tomorrow                    Rs 4,850  [Mark paid]
            School fee         Fri 14 Nov · estimated      Rs 12,000 [Mark paid]
Section     Paid · 4
Rows        Rent               [chip: Paid]                Rs 30,000
```

- Estimated amounts say "estimated" in words; the `~` is removed.
- Mark paid is a labelled tonal button.
- **Empty:** "Add what you pay every month" with an Add payment button.

## 4.12 Expense and paid sheets

**Expense sheet:** title "Add expense", a labelled amount field (large, tabular), category chips, date row with an edit affordance, optional note, pinned "Add expense". Delete sits in the sheet's overflow, acts at once and offers Undo.

**Paid sheet:**

```
Sheet       School fee paid                                [x]
            Amount   [ Rs 12,000 ]
            Attach a receipt (optional)
            [Scan receipt]   [Choose file]
Bottom bar                                 [ Done ]
```

- The primary button is **Done**, not Skip. The two attach options are outlined and wrap onto two lines when needed. (Decided, D6.)

## 4.13 Onboarding

```
App bar     (back)          Step 2 of 4  [progress bar]     Skip
Body        Headline (headlineSmall), one line of body text
            Step content
Bottom bar                                 [ Continue ]
```

- A progress bar and "Step n of 4" on every step; Back on steps 2 to 4; one pinned primary button.
- **Step 1, who are you:** five selectable cards with an icon and one line each; the selected card has a 2 dp border and a check.
- **Step 2, first scan:** primary is "Scan a document"; Skip is the text button in the app bar only.
- **Step 3, monthly payments:** tapping a chip opens a small sheet with amount and day and its own Save; the page's button stays "Continue" and nothing is lost by pressing it.
- **Step 4, done:** a success state with the first forecast in a hero card ("Your November: Rs 54,500 across 4 payments"), then a list-block row "Remind me before due dates" with a switch. The system permission prompt appears only when the user turns the switch on. Primary: "Go to my dashboard".

## 4.14 More and Settings

**More**

```
Hero card   [avatar] Owais                                  >
            Free plan · "Upgrade to Premium"                (tonal button)
List block  [icon] Auto Tasks            14 created this month   >
            [icon] AI assistant          Off                      >
List block  [icon] Settings                                       >
            [icon] Trash                 3 items                  >
```

**Settings** becomes a short menu of grouped pages instead of one long list:

```
List block  [icon] Security              App lock on              >
            [icon] Notifications         Digest 8:00 AM           >
            [icon] Appearance            Flagship · System        >
            [icon] Language and region   English · PKR            >
            [icon] Calendar              2 calendars              >
            [icon] Data and backup       Last export 3 Nov        >
List block  [icon] Diagnostics                                    >
            [icon] About                 Version 1.0.0            >
```

- Each row shows its current state as the trailing value.
- Language lives only under "Language and region" (Profile links to it). Trash lives only in More.
- Premium and AI move up to More. (Decided, D7.)
- **Appearance page:** theme mode as a three-way switch; the three looks as selectable cards, each with a small preview and one line ("Compact and dense", "Warmer and rounder", "Larger text and more space"); a text-size slider. The slider is a new setting. (Decided, D8.)
- **Data page:** export options as rows. "Delete all data" sits alone at the bottom in its own list block, in danger colour, behind the existing double confirmation.
- Quiet hours opens one sheet with From and To, not two unlabelled pickers.

## 4.15 Premium

```
App bar     (close)
Body        Headline (headlineSmall): "Do more with LifeOS Premium"
List block  [check] Unlimited documents in your Vault
            [check] Unlimited auto tasks
            [check] ...                                     (every real benefit, one line each)
Hero card   Rs 499 per month
            "Cancel anytime in the Play Store or App Store"
Bottom bar  [ Subscribe ]
            Restore purchase  (text button)
            Terms · Privacy   (text links)
```

- Today the screen lists two benefits: the document limit and the auto-task limit (`features/premium/ui/premium_screen.dart:58-59`). List every benefit that exists in the build, such as AI help if it is Premium-only, and no planned ones. The price shown above is a placeholder; the real price comes from the store.
- Subscribe shows a spinner while the store sheet is open. Success closes the screen and shows a snackbar "You're on Premium". A failure shows the reason in a danger status line above the bar.
- Already subscribed: the hero card shows the plan and renewal date; the primary button becomes "Manage subscription".
- The no-account note uses `onSurfaceVariant`, not the low-contrast `outline` colour.

## 4.16 App lock

- The icon matches the unlock method the device will use (fingerprint, face or PIN).
- After a failed or cancelled attempt: one line, "Couldn't verify. Try again.", and the button stays.

## 4.17 Rule for every remaining screen

Auto Tasks list and detail, add-rule sheet, Attention list, Expiring, Trash, Share history, Bundles, Profile, AI settings and Diagnostics follow the same recipe:

1. Wrap the data in `AsyncBody`; give the screen a skeleton, an empty message with one action, and an error with Retry.
2. Use `TabScaffold` with at most two app-bar actions.
3. Replace private section titles with `SectionHeader`.
4. Put grouped fields in list blocks; leave long same-kind lists as plain rows.
5. Decide the one primary action and pin it if the screen is a form or a flow.
6. Apply the destructive action pattern.
7. Swap system emoji for icons and raw sizes for tokens.
8. Run the checklist in 3.7.

Screen-specific notes:
- **Add-rule sheet:** show name, amount and due day first; cycle, skip months, reminders and person go under "More options". Check the free-tier limit **before** opening the sheet.
- **Rule detail:** every field saves the same way. Use the pinned Save for all of them, including the on/off switch, and warn on back if there are unsaved changes.
- **Trash:** add "Empty trash" in the overflow (irreversible, confirmed). Restore shows a snackbar.
- **Diagnostics:** label each device fact; hide the "test error" button in release builds.
- **AI settings:** the advanced form is collapsed by default; Save confirms with a snackbar; switching to managed mode asks before removing a stored key.

---

# Part 5 — Rollout order

Each slice ships by itself, keeps the app working, and ends with `flutter analyze` clean and the full test suite passing. Slices 0 to 2 change shared code and unblock everything after them.

| Slice | Scope | Done when |
|---|---|---|
| **0. Foundation** | Tokens for colour roles, score and area light/dark values, radius scale, icon and emoji sizes, motion. `AppColors` theme extension. Full text theme. Bundled Inter and Noto Naskh Arabic. Themes for cards, chips, buttons, inputs, dialogs, sheets, snackbars. | New tests: every colour pair in 3.1 meets its contrast ratio against the real generated scheme, in light and dark, for all three looks. The literal scan (`test/design/style_literal_test.dart`) covers colour, `fontSize:` and corner-radius literals in `lib/features/` as a ratchet: the counts measured in slice 0 (23, 24 and 13) may only go down, and each later slice lowers them towards zero. `Duration(` is not scanned, because feature code has legitimate non-motion durations. PBI-031's tests still pass, including Classic's exact values. |
| **1. Shared components and states** | `AsyncBody`, extended `EmptyState`, `Skeleton`, `SectionHeader` (five copies removed), hero card, stat tile, list block, status / area / delta chips, bottom action bar, icon action bar, `SheetFrame`. Chart updates in 3.5, including the mirrored sparkline. | Each component has widget tests in light and dark, all looks, English and Urdu, at text scale 1.0 and 1.3. |
| **2. Safety and consistency** | The destructive action pattern on every screen. Start/end fixes for swipe backgrounds and alignments. Tooltips and screen-reader labels. Reduce-motion. Save-on-back for task title and notes. | A test per destructive action checks for Undo or a danger-styled confirmation. No `Alignment.centerLeft`, `centerRight`, `EdgeInsets.only(left:` or `right:` remain in `lib/features/`. |
| **3. Money** | Overview (4.10), Forecast (4.11), expense and paid sheets (4.12). Closes F-02. | Density test for Money updated; owner approves screenshots. |
| **4. Home and Life Score** | 4.1, 4.2. | PBI-031's Home density target still met: score card, three attention items, five tasks and the money tile without scrolling at 412 × 892 dp. |
| **5. Tasks** | 4.3, 4.4, 4.5. | Tasks → Today still shows at least 15 rows at 412 × 892 dp, or the owner accepts a lower number in exchange for the load tile and full-width switch. |
| **6. Vault** | 4.6, 4.7, 4.8. | Journey 3 in the UI flow document (find a document and share it) still takes five taps or fewer. |
| **7. Scan review** | 4.9. | A correctly read bill saves in two taps. |
| **8. More, Settings, Profile** | 4.14. | Every setting reachable in three taps or fewer from the More tab. |
| **9. Onboarding, Premium, lock, AI** | 4.13, 4.15, 4.16. | Onboarding can be completed, and backed out of, at every step without losing input. |
| **10. Remaining screens** | 4.17. | The checklist in 3.7 passes on every screen. |

For each screen slice, attach before and after screenshots in light and dark, English and Urdu, for the owner's approval, as PBI-031 did.

**What this plan does not touch:** data, services, providers, database schema, routes, deep links, notification behaviour, or the navigation structure. If a redesign turns out to need data that is not already exposed, stop and raise it.

---

# Part 6 — Owner decisions

All nine were accepted as recommended by the owner on 2026-11-11.

| # | Topic | Decision |
|---|---|---|
| D1 | Urdu typeface | Noto Naskh Arabic. Nastaliq is not used. |
| D2 | Section headers | Sentence case, no letter spacing. This replaces PBI-031's "small caps" wording. |
| D3 | Large text | No clipping at 200% system text size on the five tab screens, sheets and dialogs; best effort elsewhere. 1.3× stays the minimum everywhere. |
| D4 | Onboarding finish | A still success state. No confetti. |
| D5 | Completed tasks (F-01) | A Completed view under the Tasks overflow menu. Archived tasks are decided separately. |
| D6 | Paid sheet button | The primary button is "Done", not "Skip". |
| D7 | Premium and AI | Moved from the bottom of Settings to the More tab. |
| D8 | Text size | A text-size slider under Appearance, using the existing `textScale` column. This is a small new setting. |
| D9 | Fonts | Inter and Noto Naskh Arabic are bundled with the app (about 1 MB). |

Follow-ups these decisions create outside this document:
- **D2:** `PBI/PBI-031-flagship-compact-layout.md` still says "small caps"; note the change there when slice 1 ships.
- **D4:** `LifeOS-Founders-Pack/lifeos-ui-flow.md` (onboarding step 4) still says "confetti-lite".
- **D5:** F-01 in `PBI/PBI-038-testing-feedback.md` is covered by slice 5; the Archived question stays open there.
- **D8:** the slider writes a setting, so it is the one place this plan goes beyond presentation.

---

*End of document. Build from Part 3 and Part 4; use Part 1 to check nothing was missed.*
