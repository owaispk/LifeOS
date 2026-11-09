# PBI-031 — Flagship: Compact, Professional Layout

| Field | Value |
|---|---|
| Epic | E5 Platform / Design |
| Priority | P1 (polish before launch) |
| Story Points | 5 |
| Spec refs | UI flow §5 (design tokens), Features §10 "max 1 screen of content before scroll"; PBI-025 look templates |
| Depends on | PBI-001 (tokens, theme), PBI-025 (Flagship / Funky / Classic) |
| Status | In Progress |

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
| Vault home | 8 folders | all 9 (8 system + Unfiled) |
| Money → Overview | 4 expense rows | ≥ 6 |

Note: Tasks Today already shows 11 rows, more than AC1's absolute minimum of 9, so the 30% rule (≥ 15) is the binding target.

**Implementation choice:** `Tokens.space*` become getters that read the current look's spacing scale (`AppSpacing.current`, set by the app whenever the look changes). This works like the app language (`AppLocale`, PBI-025). Every existing call site picks up the new scale without rewriting about 275 lines; only `const` expressions that used them change.

