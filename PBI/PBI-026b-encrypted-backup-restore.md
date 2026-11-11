# PBI-026b — End-to-End Encrypted Backup & Restore

| Field | Value |
|---|---|
| Epic | E5 Platform / Cloud |
| Priority | P1 (post-MVP; the main Premium driver: "what if I lose my phone?") |
| Story Points | 13 |
| Spec refs | Features §1.6 ("E2E encrypted cloud backup — server cannot read documents"), §14 (Backup: off / Wi-Fi only / always), §15; Data model §1.6–1.7, §4.4 blob sync, §5.1, §6.2 `/files/presign`, `/files/confirm` |
| Depends on | PBI-026a (account, wrapped Master Key), PBI-024 (file encryption), PBI-029 (Premium) |
| Status | Ready (blocked by 026a) |

## User Story
As a **Premium user**, I want my documents and data backed up automatically and encrypted so only I can read them, so that if I lose my phone I can install LifeOS on a new one, enter my recovery phrase and get everything back.

## Description
Backup is **one-way plus restore**: this phone uploads; a new phone restores. Live two-way editing across phones is 026c. Doing backup first delivers the main Premium promise without the conflict rules.

### What is backed up
- **Document files:** already AES-256-GCM ciphertext on the phone (PBI-024). They upload **as-is** to object storage (Cloudflare R2, per the data model) through presigned URLs. The server and R2 only ever hold ciphertext; the file keys stay wrapped by the Master Key, which the server can't unwrap.
- **Rows:** every synced table (documents, tasks, payments, expenses, rules, settings…). They go to Postgres through the existing outbox (`pending_ops`, PBI-002), pushed in batches.
- **Sensitive text columns are encrypted before upload** (decision below): document titles, OCR text, extracted field values, reference numbers, task titles and notes, payment titles and person names. They're stored server-side as ciphertext (AES-256-GCM with a key derived from the Master Key). The server can still order, count and enforce quotas without reading content.

### Backup modes (Settings, spec §14)
- **Off** (default until an account exists), **Wi-Fi only** (default once backup is turned on), **Always**.
- Runs on change (debounced), on app start and resume, and through Android WorkManager when charging and on Wi-Fi. A large first backup continues in the background, resumes after interruption, and shows progress in Settings ("Backing up 37 of 120 documents").
- Settings shows the last successful backup time and any problem in plain words ("Waiting for Wi-Fi").

### Restore on a new phone
- At onboarding (PBI-022) and in Settings: **"Restore from backup"** → sign in (026a) → enter the recovery phrase → rows download, then files.
- Lists appear as soon as the rows arrive. Files download lazily: thumbnails first, full files on open or in the background (spec §4.4). An LRU cache honours the 512 MB default.
- Reminders, the ATC schedule and Expiry Guard rebuild from the restored rows (the existing rebuild-all paths, PBI-012/013/008).

### Premium lapse and quotas
- If Premium lapses, **backup pauses**. Nothing is deleted on the server or the phone. The user can still restore an existing backup for **90 days**. After that the backup is purged, with two reminders first.
- The server enforces the free/premium quotas (data model §5.3) on presign, as a second line behind the app's own limit (PBI-029).

## Acceptance Criteria
1. **Zero-knowledge:** a test inspects every upload. File bodies are ciphertext (no PDF/JPEG header). Every sensitive column (list above) arrives encrypted. No Master Key, file key, phrase or plaintext of those columns appears in any request.
2. **Round trip:** a seeded library (documents with pages, tasks, rules, payments, expenses, settings) backs up from device A and restores on a fresh device B with the phrase. Rows match field for field, and every file decrypts byte for byte to the original.
3. **Modes:** Off sends nothing. Wi-Fi only sends nothing on mobile data (simulated) and resumes on Wi-Fi. Always uses any connection.
4. **Resumable:** killing the app mid-upload, then reopening, finishes the backup without duplicate files (each file is uploaded once, keyed by `r2_key` and its SHA-256).
5. **Offline-first:** with no network, the app behaves as today. The outbox grows, and nothing blocks or errors on screen.
6. **Lazy restore:** after a restore, lists and search work before all files have arrived. Opening a document downloads, verifies the SHA-256 of the ciphertext, then decrypts.
7. **Lapse:** with Premium lapsed, backup pauses with a clear message and nothing on the server is deleted. Restore still works within 90 days (server test with clock control).
8. **Server:** RLS blocks cross-user access to rows and presigned URLs (test with two users). Presign refuses a file over the quota or another user's document.
9. **Battery and data:** background backup only runs under the chosen network rule. Device QA checks a 100-document first backup on Wi-Fi finishes and resumes after a reboot.
10. EN/UR strings for every new screen and message, and no layout overflow (PBI-031 AC4 checks extended to Backup screens).

## Out of Scope
- Two-way sync and conflict handling between two active phones (026c).
- Server-side search (OCR text is encrypted, so search stays on the phone; see Decisions).
- Household sharing, web access.

## Grooming Notes (2026-11-10)
- **Decision, deviating from the data model:** data model §5.1 stores `ocr_text` plaintext on the server for search, with an optional "Private search mode". LifeOS has **no server-side search** (search is on-device FTS, PBI-006), so plaintext buys nothing and costs trust. This PBI encrypts the sensitive columns by default; the data model should be updated to match. Flagged for product-owner confirmation; the cost of reversing it later is low.
- **Column encryption:** a separate "row key" derived from the Master Key with HKDF (`info = "lifeos-rows-v1"`), using AES-GCM per value with a random nonce. Encrypted columns are stored as `bytea`/base64 text. Non-sensitive columns (ids, dates, amounts, statuses, foreign keys) stay plain so the ATC cron and quotas can work later.
- **Amounts:** kept plain (numbers without titles reveal little, and the planned server-side forecast and ATC cron need them). Listed for the product owner to confirm alongside the decision above.
- **Upload path:** `POST /files/presign` (Edge Function: checks the JWT, quota and ownership) → PUT the ciphertext to R2 → `POST /files/confirm`. Then the row's `r2_key` is set and synced.
- **Batches:** ≤ 500 ops per push (data model §4.2). Row pushes use the existing `pending_ops` payloads with column encryption applied at send time, so the local database stays plaintext and fast (it is already protected at rest by app lock and the device's encryption).
- **Background:** the `workmanager` package with network and charging constraints. Foreground sync runs while the app is open.
- **Prerequisite outside the code:** an R2 bucket and its API token, created by the product owner. The agent can't create cloud accounts.
- **Estimate:** 13, the largest in the backlog. If it runs over, the natural split is (i) rows and restore, then (ii) files and lazy download.
