# PBI-020 — Daily Life Score v1

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §9; UI flow §1.1; Data model §3.5, §6.4 |
| Depends on | PBI-009, PBI-013, PBI-008 |
| Status | Ready |

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
