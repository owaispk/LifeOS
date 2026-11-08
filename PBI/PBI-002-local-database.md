# PBI-002 — Offline-First Local Database (Drift)

| Field | Value |
|---|---|
| Epic | E0 Foundation |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Data model §1, §3.1–3.5, §4.1, §8 |
| Depends on | PBI-001 |
| Status | Ready |

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
