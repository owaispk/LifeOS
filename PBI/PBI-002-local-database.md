# PBI-002 — Offline-First Local Database (Drift)

| Field | Value |
|---|---|
| Epic | E0 Foundation |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Data model §1, §3.1–3.5, §4.1, §8 |
| Depends on | PBI-001 |
| Status | Done |

## User Story
As a **user**, I want all my data stored on my phone so that the app works fully offline.

## Description
Implement the local Drift (SQLite) schema that mirrors the Postgres model:
`persons, folders, documents, document_files, extracted_fields, tasks, subtasks, task_reminders, atc_rules, categories, payments, expenses, score_snapshots, user_settings`, plus the local-only tables `pending_ops`, `conflict_log` and `blob_cache`.

Rules:
- IDs are client-generated **UUIDv7**.
- Every syncable table has `updated_at`, `deleted_at` and `version`.
- Timestamps are stored as UTC epoch-ms integers.
- Money is stored as integer minor units (`amount_minor`). Never floats.
- Soft delete only. Repositories filter out `deleted_at IS NOT NULL` by default.
- Every write also appends a `pending_ops` outbox entry, ready for future sync.
- Seed data on first run: one "Me" person, the 8 system folders (Identity, Education, Medical, Bills & Receipts, Property, Vehicles, Insurance, Work), the system categories (rent, fees, utilities, internet, mobile, installment, subscription, other), and default `user_settings`.

## Acceptance Criteria
1. The schema compiles with Drift codegen, and migration v1 creates all of the tables above.
2. A unit test creates, reads, updates and soft-deletes a row in each table through its repository.
3. Every insert/update/delete writes exactly one `pending_ops` row with the correct `op` and `base_version`.
4. Updating a row increments `version` and refreshes `updated_at`.
5. A fresh install contains the seeded person, 8 folders, categories and settings (verified by test). Re-running the seed creates no duplicates.
6. Amount helpers convert "Rs 4,850" to and from 485000 minor units with no rounding errors (tested).
7. UUIDs are generated without network access and sort by creation time.

## Out of Scope
Server sync (PBI-026), encryption of blobs (PBI-024).

## Implementation Notes (2026-11-08)
Code: `SourceCode/lifeos_app/lib/{core/ids.dart, core/money.dart, data/}` — drift 2.35, sqlite3 3.5.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | `data/db/tables.dart` + `app_database.dart` (schema v1, `createAll`, FKs on). `schema_test.dart`: all 18 tables exist, sync columns on every synced table, money columns are INTEGER, FKs enforced. |
| 2 | ✅ | `SyncRepository` per table via `Repositories`. `repository_test.dart` runs create → read → update → soft delete on all 14 synced tables. |
| 3 | ✅ | Same test: exactly 3 `pending_ops` per row — insert/0, update/1, delete/2 — payload is the row after the write. A failed write leaves no row and no op (one transaction). |
| 4 | ✅ | Version 1 → 2 → 3, `updated_at` strictly increases (fake clock). Callers can't set id/user_id/version. |
| 5 | ✅ | `seed.dart` (natural-key idempotent). `seed_test.dart`: Me + 8 folders + 8 categories + settings; re-seeding adds nothing. Runs at app start via `openLocalData()` (mobile/desktop). |
| 6 | ✅ | `Money.parseMinor/format`, integer-only, Urdu/Arabic digits. `money_test.dart` incl. exact round-trips. |
| 7 | ✅ | `IdGenerator` (UUIDv7, RFC 9562 counter method, monotonic even if the clock goes backwards). `ids_test.dart`: 10k ids in one ms stay strictly sorted. |

`flutter analyze`: no issues · `flutter test`: 51/51 passed (40 new).

Decisions / deviations from the data model:
- `date` columns are stored as `'YYYY-MM-DD'` text and `time` as `'HH:mm'` (spec only fixed timestamps → epoch-ms); both sort correctly and carry no timezone.
- `user_settings` and `score_snapshots` use an `id` primary key like every other synced table; the spec's natural keys (`user_id`, `user_id+day`) are unique constraints instead. This keeps one generic repository/sync path.
- `document_files` adds `local_path` and makes `r2_key`/`enc_*` nullable until backup (PBI-026) and encryption (PBI-024) exist.
- Before signup there is no server user: a local user id (UUIDv7) is created once and stored in the local `app_meta` table.
- Not created yet (no feature needs them): `users`, `devices`, `document_shares`, `households` — they arrive with PBI-026/028.
- Web preview skips the database (Drift on web needs sqlite3.wasm assets); the UI doesn't read data yet.
- Not yet verified: opening the real on-device database file (`AppDatabase.open()`); all tests use in-memory SQLite. Checked when the app first runs on Android.
