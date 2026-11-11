# PBI-026a — Optional Account & Recovery Phrase (cloud foundation)

| Field | Value |
|---|---|
| Epic | E5 Platform / Cloud |
| Priority | P1 (post-MVP; Premium driver) |
| Story Points | 8 |
| Spec refs | Features §13 ("No account required… Signup prompted only when cloud backup/sync is wanted"), §14, §15; Data model §1, §3.1 (`users`, `devices`), §5.1 key hierarchy, §5.2 RLS, §5.3 API rules |
| Depends on | PBI-024 (Master Key, file keys), PBI-029 (Premium entitlement), PBI-025 (Settings) |
| Status | Ready |

## User Story
As a **Premium user** who is afraid of losing my phone, I want to create an account protected by a recovery phrase that only I hold, so my data can be backed up and restored later — **without** the company ever being able to read my documents.

## Description
LifeOS has had no accounts, no login and no server on purpose (PBI-029: "LifeOS has no users table"). This PBI adds the **minimum** cloud identity the backup and sync PBIs (026b, 026c) and the share links (028b) need. Local mode stays the default forever: no feature that works today may start requiring an account.

### When the account appears
- Only from **Settings → Backup & sync** (and the Premium screen's "Back up my data" button). Never at onboarding, never as a wall.
- Sign-up methods: **email one-time code** (no passwords to forget) and **Sign in with Google** on Android. Phone/SMS OTP is out of scope (cost).
- Creating an account **requires an active Premium entitlement** (PBI-029), because backup and sync are Premium. A lapsed subscription never deletes an account or its backup (see 026b).

### The recovery phrase (the trust feature)
- At sign-up the app shows a **12-word recovery phrase** (BIP-39 English word list), generated on the phone.
- The existing Master Key (PBI-024) is wrapped with a key derived from that phrase: **Argon2id** (memory-hard; parameters below). Only the **wrapped** Master Key goes to the server. The phrase and the plain key never leave the phone.
- The user must **confirm 3 random words** before backup can turn on. Screenshots are blocked on the phrase screen (FLAG_SECURE, PBI-024).
- The opt-in screen states plainly, in EN and UR: *"If you lose this phone **and** this phrase, your backed-up documents cannot be recovered — not even by us."* (Data model §5.1: "own it".)
- Settings offers **Show recovery phrase** (behind app lock / biometric) and **Change recovery phrase**. Changing it re-wraps the Master Key; files don't need re-encryption.

### Server (Supabase, per the data model)
- Supabase project: Auth (email OTP, Google), Postgres with **Row-Level Security on every table** (`user_id = auth.uid()`), Edge Functions.
- Tables in this PBI: `users` (id, created_at, wrapped MK, KDF salt and params, key version) and `devices` (id, user, platform, push token, last sync cursor).
- On sign-in, the phone's local user id (the `local_user_id` the app has used since PBI-002) is **re-keyed** to the server user id in one local transaction, so every existing row belongs to the account before anything syncs.
- Signing in on a **second phone** asks for the recovery phrase, downloads the wrapped Master Key and unwraps it locally. That phone can then read backups (026b).

### Sign out / delete
- **Sign out:** the phone keeps its data and returns to local mode; the backup stays on the server.
- **Delete account** (Settings, double confirm like PBI-025): queues the server-side purge of rows, blobs and keys within **30 days** (Features §14), revokes all share links (028b) and signs out. The local data on this phone is kept unless the user also chooses "Delete all local data".

## Acceptance Criteria
1. Without an account, every existing feature works exactly as before (full regression suite passes with no network).
2. An account can only be created with an active Premium entitlement. The entry points are only Settings → Backup & sync and the Premium screen.
3. The recovery phrase is 12 BIP-39 words generated on the device. Sign-up can't finish until 3 randomly chosen words are typed back correctly.
4. Only the Argon2id-wrapped Master Key reaches the server. A test captures every request during sign-up and asserts that neither the phrase nor the raw key appears in any body, header or log.
5. A second device that signs in and enters the phrase unwraps the same Master Key: a file encrypted on device A decrypts on device B (integration test against a local Supabase).
6. A wrong phrase fails cleanly ("That phrase doesn't match"). After 5 wrong attempts the app waits 5 minutes. Nothing is overwritten.
7. RLS: a user's JWT cannot read or write another user's `users` or `devices` rows (SQL test with two users).
8. Delete account removes the server rows and wrapped key (a server test checks they're gone) and schedules the blob purge. Local data stays unless separately deleted.
9. Every new screen is in EN and UR (PBI-025 AC2 still holds), and the phrase screen blocks screenshots.

## Out of Scope
- Uploading data or files (026b), multi-device sync (026c), share links (028b).
- Household / family accounts (spec P2).
- Passwords, SMS OTP, Apple sign-in (iOS sign-in follows the iOS track).
- Any server-side reading of document content.

## Grooming Notes (2026-11-10)
- **KDF parameters:** Argon2id, 64 MiB memory, 3 iterations, parallelism 1, 16-byte salt. That's about 0.5–1 s on a mid-range phone. Package: `cryptography` already has Argon2id; check its speed on the emulator, and fall back to a native implementation if it takes over 2 s.
- **Key versioning:** the `users` row stores the KDF parameters and a key version, so parameters can be raised later and the key re-wrapped on next sign-in.
- **Client packages:** `supabase_flutter` (Auth, PostgREST, Functions); `google_sign_in` for Android.
- **Re-keying `user_id`:** one Drift transaction updates every synced table and clears nothing from `pending_ops`, so the outbox is ready for 026c. It's covered by a migration-style test on a database seeded with Sprint 1–6 data.
- **Prerequisite outside the code:** the product owner creates the Supabase project (free tier is enough to start) and the Google OAuth client. The agent can't create accounts. Keys go in build-time environment config, never in the repo.
- **Privacy copy:** the Settings privacy screen (PBI-025) gains a "What we store" section listing exactly the server tables, in plain words.
- **Testing:** a local Supabase (`supabase start` in Docker) for the integration tests. Unit tests fake the auth client.
