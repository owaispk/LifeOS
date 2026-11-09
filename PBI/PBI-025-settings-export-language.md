# PBI-025 — Settings, Data Export & English/Urdu

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 5 |
| Spec refs | Features §14; UI flow §5.6 |
| Depends on | PBI-001, PBI-024 |
| Status | Done (Urdu copy pending native-speaker review) |

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

## Grooming Notes (Sprint 6, 2026-11-09)
**Settings screen:** More → Settings (`/more/settings`), in groups:
- Security: app lock, Vault lock, auto-lock minutes, screenshot blocking.
- Notifications: digest time, quiet hours, per-domain toggles.
- Language: English / اردو.
- Appearance: theme mode, look template.
- Data: export, Trash, delete all local data.
- Premium: a stub row, "Coming soon".

All values live in `user_settings`. Schema v6 adds `language` ('en' | 'ur') and `screenshot_block`.

**Localisation**
- Flutter gen-l10n with `lib/l10n/app_en.arb` + `app_ur.arb`; `MaterialApp.locale` follows the setting, so switching needs no restart. Urdu is RTL through `GlobalMaterialLocalizations`.
- In widgets: `context.l10n.key`.
- Domain helpers that return display text (score labels, attention "due tomorrow", relative days, month names, cadence labels) take the localisations object.
- Notification text is localised with `lookupAppLocalizations(locale)` in `ReminderSync`.
- Text written into the database when it's created stays as written: ATC-generated task titles like "Rent — Rs 45,000" are user data the user can edit.

**AC2 check:** a test scans `lib/` (except `l10n/` and generated files). It fails on string literals used directly in `Text(...)`, or in named UI arguments (`label:`, `title:`, `tooltip:`, `hintText:`, `labelText:`, `helperText:`, `message:`, `actionLabel:`, `semanticsLabel:`, `content: Text`). Emoji-only and punctuation-only literals are allowed.

**Urdu copy:** a first translation is written during dev and marked for review by a native speaker before release.

**Themes**
- Mode: system / light / dark.
- Templates: Flagship (default), Funky (a different seed colour and rounder shapes), Classic (large text: `textScaler` ≥ 1.3, larger touch targets).

**Export:** a ZIP built in an isolate and shared through the share sheet:
- `documents/<Folder>/<title>.<ext>`: decrypted, every live document.
- `data/<table>.csv`: one per synced table, live rows.
- `data/export.json`: everything.

The temporary ZIP is deleted after sharing.

**Delete all local data:** confirmed twice (the second time by typing DELETE). It deletes the database rows, the vault files and the secure-storage keys, then the app restarts into onboarding.

## Dev & QA Notes (Sprint 6, 2026-11-09)
Code:
- `lib/features/settings/settings_screen.dart` (`/more/settings`), `settings_providers.dart`, `data/data_service.dart` (export, delete-all).
- `lib/core/l10n.dart` (`context.l10n`, and `l10nNow` for helpers without a context).
- Gen-l10n with `lib/l10n/app_en.arb` + `app_ur.arb`, generated from the English/Urdu pairs in `tool/l10n/strings_*.py` (`python tool/l10n/build_arb.py && flutter gen-l10n`). **697 keys.**
- Themes: Flagship / Funky / Classic in `app_theme.dart`.
- Schema v6: `user_settings.language`, `screenshot_block`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: tapping اردو switches the Settings title to "سیٹنگز" and `Directionality` to RTL with no restart; English switches back. **Device:** the whole app (tabs, Home, Settings) switched instantly and mirrored. |
| 2 | ✅ | `test/l10n_test.dart` scans `lib/` (excluding l10n and generated files) for literals in `Text(...)` and 19 UI arguments: **0**. 303 literals were moved, plus helper-built words: dates, weekdays and months, score labels, attention texts, doc types, folder and category names, cadences, notification texts. A second test checks that every key exists in both languages with the same placeholders. |
| 3 | ✅ | Service test: the ZIP has `documents/Identity/Passport.pdf` (decrypted, starts `%PDF`) and both pages of a JPEG document. The trashed document is excluded. There's a CSV for each of the 14 tables and `export.json`. |
| 4 | ✅ | Widget: Classic → `textScaler` ≥ 1.3. |
| 5 | ✅ | Widget: Delete → Continue → the button stays disabled until "DELETE" is typed → rows, Vault files and keys are gone and defaults reseeded → onboarding shows. |

**Found in dev:** the auto-lock dropdown labels ("5 min in the background") overflowed the tile, so Settings failed to lay out. They now read "5 min", with the wording moved to the title.

**Known limits:**
- The Urdu copy is a first translation and needs a native speaker's review.
- Stored text keeps the language it was created in: ATC task titles, auto-generated document titles like "K-Electric Bill — Nov 2026", and the "Me" profile name.
- Ordinals (1st, 2nd) stay English.

`flutter analyze`: no issues · full suite **457/457 passed**, identical on two runs · schema v6 migration tested from v1–v5 · device checks on the Android 17 emulator (2026-11-09).
