# PBI-025 — Settings, Data Export & English/Urdu

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §14; UI flow §5.6 |
| Depends on | PBI-001, PBI-024 |
| Status | Ready |

## User Story
As a **user**, I want to control security, notifications and language, and take my data out at any time.

## Description
- Settings groups: Security · Notifications · Language · Data · Appearance · Premium (stub)
- Language: English / اردو with an instant switch (no restart), using Flutter `intl` ARB files and RTL layout for Urdu
- Themes: light/dark/system, plus the look templates Flagship / Funky / Classic (large text for elders)
- Export everything: a ZIP of decrypted PDFs plus CSV/JSON of all tables, shared via the OS share sheet
- Trash access. "Delete all local data" with a double confirmation.

## Acceptance Criteria
1. Switching to Urdu changes all visible strings and mirrors the layout without a restart.
2. No hard-coded user-facing strings remain in `lib/` (lint/test check).
3. The export ZIP contains every non-deleted document and one CSV per table. Re-importing isn't required.
4. The Classic template raises the text scale to at least 1.3×.
5. "Delete all local data" removes the database, files and keys, then returns to onboarding.
