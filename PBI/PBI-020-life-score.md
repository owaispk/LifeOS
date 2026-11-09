# PBI-020 — Daily Life Score v1

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §9; UI flow §1.1; Data model §3.5, §6.4 |
| Depends on | PBI-009, PBI-013, PBI-008 |
| Status | Done |

## User Story
As a **user**, I want one number every morning that tells me how well my life admin is under control, and what to fix.

## Description
- v1 components: **Tasks** 30% (yesterday's completion rate; ATC payments weigh double), **Payments** 25% (nothing overdue = full marks; each overdue item subtracts), **Documents** 15% (no documents inside the expiry danger window)
- The Health / People / Balance weights (30%) are redistributed proportionally while those modules are unused. Unused domains never reduce the score.
- Weights live in a shared, version-pinned `score_weights.json`
- Output: score 0–100, components, and `drags[]` (the exact items pulling the score down, with points)
- A daily snapshot is written to `score_snapshots` (once per day, idempotent)
- Detail screen: big ring, 7-day sparkline, component bars, and the drag list with one-tap fixes
- Tone rules: never guilt language. Below 40 → triage mode: "Heavy week? Here are the 3 highest-impact items".
- Ring colours: under 40 red, 40–69 amber, 70 and up green

## Acceptance Criteria
1. A new user with no data scores 100 (nothing to punish), not 0.
2. The score engine is a pure function with at least 15 unit tests covering weights, redistribution, double-weight payments, and the 0/100 bounds.
3. Every drag item references a real task/payment/document id and the points it costs.
4. The sum of component contributions equals the displayed score (±1 for rounding).
5. Snapshots: computing twice on the same day upserts one row.
6. Copy review: no string contains "failed", "missed" or other guilt words (string test).

## Grooming Notes (Sprint 5, 2026-11-09)
**Weights:** `assets/score_weights.json` (version 1): tasks 30, payments 25, documents 15, health 15, people 10, balance 5. The engine takes a `ScoreWeights` value, so tests don't need assets.

**Active components in v1:** Tasks, Payments and Documents. Health, People and Balance have no modules yet, so they are unused and their 30% is spread proportionally: 42.86 / 35.71 / 21.43.

**Tasks** (yesterday's completion)
- Counts tasks due yesterday that aren't deleted. Done tasks count; open or skipped ones don't.
- ATC tasks weigh 2, others 1.
- No tasks due yesterday -> full marks.
- Each task not done is a drag worth its share of the component.

**Payments**
- Overdue = not paid or skipped, and the due date is before today.
- Each overdue payment costs 1/3 of the component, capped at the component (with more than 3, each costs component / n).

**Documents**
- Danger window = live, not archived, with an expiry date on or before today + 30 days (including already expired).
- Each such document costs 1/3 of the component, capped the same way.

**Output**
- Score = round(sum of contributions), clamped to 0-100.
- Drags: `{kind, id, title, points}` with points < 0 rounded to 1 dp, most costly first.
- Kinds: `task`, `overdue_payment`, `expiring_document`.

**Snapshot:** one row per local day, `(user_id, day)` upserted every time the score is computed: at app start, on resume (after the ATC generator and Expiry Guard run) and on Home pull-to-refresh. Delta = today - yesterday's snapshot. *(Changed during dev: Home no longer writes on open. Screens should not start writes from their own lifecycle.)*

**Detail screen** (`/home/score`)
- Big ring with the number and a status label ("Doing well" / "A few things need you" / "Heavy week").
- 7-day sparkline of snapshots (one series, no legend, recessive axis), component bars, then the drag list with one-tap fixes:
  - Payment -> Mark paid (the completion chain)
  - Task -> Move to today
  - Document -> Open (to Mark renewed)
- Below 40, triage mode: "Heavy week? Here are the 3 highest-impact items" shows only the top 3.

**Tone (AC6):** a test scans every string in `lib/features/score/` and `lib/features/home/` for: failed, missed, fail, lazy, behind, shame, bad, should have.

## Dev & QA Notes (Sprint 5, 2026-11-09)
Code:
- `lib/features/score/domain/life_score.dart`: pure engine.
- `assets/score_weights.json`: loaded at start.
- `data/score_service.dart`: snapshot upsert and delta.
- `score_providers.dart`: live score.
- `score_screen.dart` (`/home/score`), `ui/score_ring.dart`, `ui/sparkline.dart`.
- `main.dart` writes the snapshot at start and on resume.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | No data → 100 (unit + widget "100 · All clear today ✓"). |
| 2 | ✅ | **19 pure unit tests**: redistribution (42.86/35.71/21.43), spec weights when all in use, unused domains, partial and complete days, ATC double weight, the yesterday-only window, deleted tasks, payment states, the ⅓ cap, the 30-day window edges, archived documents, 0/100 bounds, band labels, JSON, the weights file. |
| 3 | ✅ | Every drag carries the real task/payment/document id and negative points, most costly first. |
| 4 | ✅ | Component contributions and drags add up to the score within ±1, across 4 mixed scenarios. |
| 5 | ✅ | Two refreshes on one day → one row (88 after a payment went overdue). Yesterday 100 → delta −12. Widget: pull-to-refresh shows 88 and ↓12 and writes today's row. |
| 6 | ✅ | A test scans every string in `lib/features/score` and `lib/features/home`: no failed / fail / missed / lazy / behind / shame / bad / should have. |

Detail screen (widget-tested):
- Each component has its own bar.
- Drags come with fixes: Mark paid, Move to today, Open. "Move to today" lifts 45 → 88.
- Below 40, triage mode shows "Heavy week? Here are the 3 highest-impact items" and the top 3, plus "Show all".
- The ring uses the score colour plus a text label ("Doing well" / "A few things need you" / "Heavy week").
- The sparkline follows the dataviz rules: one series, no legend, 2 px line, 8 px marker on today, a single direct label, gaps for missing days, and a screen-reader summary.

**Found in dev:**
- The engine gave a clean slate 70 when Health/People/Balance were passed as "in use". Components the engine can't measure are now always redistributed.
- Home originally wrote the snapshot on open, which started a database write from a screen's lifecycle. The snapshot moved to app start and resume.

`flutter analyze`: no issues · full suite **370/370 passed** (66 new in Sprint 5), identical on two runs · schema v5 migration tested from v1–v4.
