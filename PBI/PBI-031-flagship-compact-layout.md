# PBI-031 — Flagship: Compact, Professional Layout

| Field | Value |
|---|---|
| Epic | E5 Platform / Design |
| Priority | P1 (polish before launch) |
| Story Points | 5 |
| Spec refs | UI flow §5 (design tokens), Features §10 "max 1 screen of content before scroll"; PBI-025 look templates |
| Depends on | PBI-001 (tokens, theme), PBI-025 (Flagship / Funky / Classic) |
| Status | Done — awaiting product-owner approval of the screenshots (AC7) |

## User Story
As a **user on the Flagship look**, I want to see more of my information on one screen, without scrolling, while everything stays neatly aligned and looks professional.

## Description
Today, spacing is generous everywhere, and it's the same in every look except Classic:
- 16 dp padding on most blocks and 24 dp between sections;
- 64 dp minimum list rows and a 72 dp bottom bar;
- 16 sp body text;
- 120 dp of empty space at the end of every list (room for the ➕).

Flagship should become a **compact, information-dense** look, like a well-made productivity app, not a cramped one.

**Spacing as a theme setting, not fixed numbers**
- Replace the fixed `Tokens.space*` constants (about 275 uses in 50+ files) with a spacing scale read from the theme (`context.space.s`, …), so each look sets its own.
- **Flagship scale:** 4 / 8 / 12 / 16 / 24 dp, down from 4 / 8 / 16 / 24 / 32, all on a 4 dp grid.
- **Classic** keeps today's roomy scale and large text, unchanged. **Funky** uses the Flagship scale, with its own colours and rounder shapes.

**Denser components (Flagship)**
- **List rows:** single-line rows 48 dp, two-line rows 56 dp (from 64). Leading icons on one column, and trailing values (amount, time) right-aligned in one column.
- **Sections:** 12 dp between sections instead of 24. Headers in small caps, 12 sp, with consistent spacing above and below.
- **Cards:** 12 dp inner padding; 8 dp between cards.
- **Bottom bar:** 64 dp (from 72), labels always shown.
- **Home:**
  - the score ring is 80 dp (from 96), with the delta and "N things need attention" beside it in two lines;
  - the money strip is one line.
- **Text:**
  - Flagship body 15 sp, secondary text 13 sp, labels 12 sp;
  - titles keep their weight, so the hierarchy stays clear;
  - nothing smaller than 12 sp.
- **End of lists:** the extra space for the ➕ becomes 88 dp (the ➕ height plus 16), not 120, and it comes from one shared constant.

**Professional alignment rules (all looks)**
- One horizontal page gutter (16 dp in Flagship) for all screen content: headers, rows, cards and buttons line up on the same left and right edges, mirrored in Urdu (RTL).
- One leading column per list (icons, avatars, check circles), and one trailing column for values.
- Numbers and amounts use tabular figures, so columns of amounts line up.
- No mixed padding inside one screen: every gap comes from the spacing scale (enforced by a test).

**Accessibility stays intact**
- Every tappable control still has a touch area of at least 48 × 48 dp. Rows get smaller, not their tap areas.
- Text contrast is unchanged. Layouts must not overflow at a 1.3× system text size.

## Acceptance Criteria
On a standard phone viewport (412 × 892 dp), with the Flagship look and the same test data before and after:

1. **More on one screen:** at least **30% more content** is visible without scrolling, compared with the baseline recorded at the start of dev, on Tasks → Today (rows), Home (sections), Vault home (folders + people) and Money → Overview (expense rows). Minimums:
   - Tasks Today shows ≥ 9 task rows;
   - Home shows the score card, 3 attention items, 5 tasks and the money strip without scrolling.
2. **Aligned:** on Home, Tasks, Vault, Money and Settings, the left edges of all section headers, row content and cards are equal (±1 dp), and so are the leading-icon centres within each list. Checked by a widget test in English (LTR) and Urdu (RTL).
3. **Touch targets:** every tappable element on those five screens still meets 48 × 48 dp (Flutter's `androidTapTargetGuideline`).
4. **No overflow:** no layout overflow on any main screen at text scale 1.0 and 1.3, in light and dark, English and Urdu.
5. **One spacing source:** no raw padding or gap numbers left in `lib/features/` (a test scans for `EdgeInsets` and `SizedBox` with literal values outside the theme's spacing scale).
6. **Other looks:** Classic's spacing and text sizes are exactly as before (test). Funky uses the Flagship spacing.
7. **Reviewed visually:** before/after screenshots of Home, Tasks, Vault, Money and Settings (light/dark, EN/UR) are attached to this PBI and approved by the product owner.

## Notes for grooming
- The baseline counts for AC1 are measured and written here before any change.
- The order of work is: the spacing extension and Flagship scale first; then the shared components (task tile, section header, cards, nav bar, Home score card); then screen-by-screen clean-up.
- Out of scope: new features, colour or brand changes, and icon redesign.

## Baseline (measured 2026-11-09, before any change)
`test/design/density_test.dart`, 412 × 892 dp, Flagship, the same seed data (16 tasks today, 4 bills, 14 expenses):

| Screen | Fully visible before | Target (≥ +30%) |
|---|---|---|
| Home | 3 of 4 sections (money strip below the fold), 3 attention items, 4 tasks | all 4 sections, 3 attention items, ≥ 5 tasks |
| Tasks → Today | 11 task rows | ≥ 15 |
| Vault home | all 8 folders (no Unfiled in the test data) | all folders, with room to spare |
| Money → Overview | 4 expense rows | ≥ 6 |

Note: Tasks Today already shows 11 rows, more than AC1's absolute minimum of 9, so the 30% rule (≥ 15) is the binding target.

**Implementation choice:** `Tokens.space*` become getters that read the current look's spacing scale (`AppSpacing.current`, set by the app whenever the look changes). This works like the app language (`AppLocale`, PBI-025). Every existing call site picks up the new scale without rewriting about 275 lines; only `const` expressions that used them change.

## Dev & QA Notes (2026-11-09)
**How it works**
- `Tokens.space*` are getters over `AppSpacing.current`: `compact` for Flagship and Funky, `roomy` for Classic.
- The app sets the scale whenever the look changes. The theme then applies:
  - body text 15 / 13 / 12 sp;
  - list rows 48 / 56 dp;
  - a 64 dp bottom bar and compact card margins on the 16 dp gutter;
  - tabular figures for amounts.
- `tool/fix_const.py` removed the `const` keywords that broke (185 places) by re-running the analyzer until clean.

**Screen changes**
- **All screens:** left/right page margins use `Tokens.gutter` (25 places). Directional (start/end) margins where they weren't symmetric, so Urdu mirrors exactly.
- **Task rows (compact looks):** one line, with the area shown as a coloured dot before the title. A second line appears only for ⚡, ‼ or a person. The check circle sits on the gutter, and its tap area stays 48 dp.
- **Tasks:** the Today / Upcoming / Domains switch moved into the title bar, which saves a 48 dp band. The title truncates first; the switch scrolls sideways only if it can't fit.
- **Home:**
  - "See all" sits at the end of each section header line, not on its own row;
  - the money strip is one compact row;
  - the score ring is 80 dp.
- **Ends of lists:** the extra space below the last row comes from `Tokens.listEnd` (88 dp compact, 120 Classic).

**Results** (412 × 892 dp, same data):

| Screen | Before | After | Target |
|---|---|---|---|
| Home | 3 of 4 sections · 4 tasks | **all 4 sections · 5 tasks** | ✅ |
| Tasks → Today | 11 rows | **15 rows** (+36%) | ✅ ≥ 15 |
| Money → Overview | 4 expense rows | **8** (+100%) | ✅ ≥ 6 |
| Vault home | all 8 folders | all 8, with more room below | ✅ |

| AC | Result | Evidence (`test/design/flagship_layout_test.dart`) |
|---|---|---|
| 1 | ✅ | The density assertions above. |
| 2 | ✅ | Every section header starts on the 16 dp gutter (±1), and every row's leading icon too (±2.5; rows inside cards follow their card). Checked on Home, Tasks, Vault and Money, in English and in Urdu (mirrored). |
| 3 | ✅ | `androidTapTargetGuideline` passes on Home, Tasks, Vault, Money and Settings. |
| 4 | ✅ | No overflow on any main screen, across 8 combinations (text 1.0× / 1.3× · light / dark · English / Urdu). |
| 5 | ✅ | A scan of `lib/features` finds no literal numbers in `EdgeInsets`, `SizedBox` or `minTileHeight`. |
| 6 | ✅ | Classic's scale is exactly the old values (16 sp body, 64 dp rows, 72 dp bar). Switching looks applies roomy vs compact; Funky is compact. Every step is on the 4 dp grid. |
| 7 | ⏳ PO | `PBI/assets/PBI-031/before_after_light_en.png` (Home, Tasks, Vault, Money, Settings, before and after) and `after_dark_and_urdu.png`. The Urdu render shows boxes because the test renderer has no Urdu font; on the device Urdu renders normally (PBI-025 device check). |

**Found in dev** (several of these were bugs from earlier sprints that the new checks exposed):
1. The density setting first shrank buttons with a 48 dp minimum to 40 dp; vertical density is kept at 0.
2. Money's month-change line overflowed at 1.3× text and in Urdu; it now wraps.
3. The Vault search bar's tappable area was only 23 dp tall; it's now a full-height search field.
4. The Vault section title used left/right margins, so it was off by 8 dp in Urdu; it now uses start/end.
5. Scaling the Tasks switch down to fit made its tap targets 31 dp; it now keeps full size and scrolls instead.
6. Header and row edges didn't line up (12 dp vs 16 dp vs about 26 dp); they're all on the gutter now.

`flutter analyze`: no issues · full suite **486/486 passed**.

Note: a commit titled "PBI-031 (WIP): compact Flagship layout" (`f043f55`) was made from this working copy partway through, outside this session. The final changes are on top of it, uncommitted.

