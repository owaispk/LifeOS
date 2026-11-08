# PBI-011 — Overload Shield

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §3.2; UI flow §2.5 |
| Depends on | PBI-009 |
| Status | Ready |

## User Story
As a **user**, I want the app to stop me from overloading a day so my plans are realistic.

## Description
- Day capacity comes from the user's working window (default 6 h, set in Settings)
- Day load = the sum of `duration_min` for open tasks due that day
- When saving a task makes a day exceed 100% of capacity, show a soft-block dialog: "Monday is already full (6.5h of 6h)", a mini week bar chart, and the buttons **Move to <suggested day>** · Pick a day · Add anyway
- Suggested day = the nearest future day under 70% load
- ATC payment tasks count toward load but are **never** blocked
- Weekly heatmap in the Upcoming view

## Acceptance Criteria
1. Adding a 60-minute task to a day with 5.5 h of 6 h load shows the dialog. Adding it to a day with 4 h does not.
2. The suggested day is the nearest day under 70%. The capacity calculator has unit tests.
3. "Add anyway" saves without changes. "Move" saves on the suggested day.
4. ATC-generated payment tasks never trigger the dialog.
5. The heatmap shows 7 days with load percentages. Days over 100% are highlighted.
