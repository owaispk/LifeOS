# PBI-026c — Multi-Device Sync (two phones, one life)

| Field | Value |
|---|---|
| Epic | E5 Platform / Cloud |
| Priority | P1 (post-MVP; Premium: "Multi-device sync") |
| Story Points | 13 |
| Spec refs | Features §15; Data model §4 (sync protocol: push/pull, cursor, conflict policy), §6.1 `/sync/push`, `/sync/pull`, §8 local-only tables |
| Depends on | PBI-026a (account), PBI-026b (encrypted upload of rows and files) |
| Status | Ready (blocked by 026b) |

## User Story
As a **Premium user with two phones** (or a phone and a tablet), I want a task I complete, a bill I pay or a document I scan on one to appear on the other within moments, without ever losing a change.

## Description
026b uploads from one phone and restores on another. This PBI makes the link **two-way and continuous**, following the data model's "dumb and reliable" protocol.

### Protocol (data model §4.2)
- **Push:** the outbox (`pending_ops`, ≤ 500 ops per batch) goes to `/sync/push`. For each op, the server applies it if `version == base_version`, then increments the version and sets `updated_at`. Otherwise it returns a **conflict** with the server row.
- **Pull:** `/sync/pull?cursor=` returns rows changed since the device's cursor (≤ 1000 per page, ordered). The phone upserts them, decrypting the sensitive columns (026b), and advances `devices.last_synced_at`.
- **When:** on start and resume, after local writes (debounced 2 s), and on a push message from the server when another device changed something (FCM data message, spec §6.5). Falls back to a 15-minute poll while the app is open if push isn't available.

### Conflict policy (data model §4.3)
- **Default:** last write wins per row (the server's `updated_at` decides).
- **Exceptions that protect the user:**
  - `tasks.status = 'done'` **always wins** over a concurrent edit. A completed task is never un-completed by sync.
  - `payments.paid_at` set wins over any other change. A paid bill never reverts to unpaid.
  - Document files never conflict: files are immutable, and a re-scan adds a new page row.
- The losing version is kept in the local `conflict_log` (already in the schema since PBI-002), and the user sees a quiet one-line note: "Updated from your other phone — Undo" (5 s). Undo re-applies the local version as a new edit.

### Side effects across devices
- Reminders: each phone schedules its own local notifications from the synced reminders. Completing a task on phone A cancels its reminder on phone B at the next sync (the existing rebuild-all, PBI-012).
- The ATC generator must not create the same occurrence twice when two phones generate offline. Generation becomes **idempotent per (rule, period)** across devices: the payment's id is derived deterministically from the rule id and period (UUIDv5), so both phones produce the same row and the second insert is a no-op.
- Life Score snapshots: one per user per day (unique key). The later write wins.
- Settings that are about the phone itself (app lock, screenshot blocking, notification permission state) **stay per device** and don't sync. Everything else in settings syncs.

### Devices
Settings → Backup & sync lists the signed-in devices (model, last sync time), with **Remove this device**, which revokes its session.

## Acceptance Criteria
1. Two simulated devices on a local Supabase: a task created on A appears on B after B's pull; edits flow both ways; deletions (soft delete) propagate.
2. **Done wins:** A completes a task while B edits its title offline. After both sync, the task is done on both and has B's title (the field-merge rule below). No device shows it open.
3. **Paid wins:** A marks a payment paid while B changes its amount offline. After sync it's paid on both, the expense is logged exactly once, and B's amount change is in B's `conflict_log` with the Undo note.
4. **No duplicate ATC occurrences:** both devices run the generator offline for the same rule and period; after sync there's exactly one task and one payment.
5. **Ordering and paging:** 2,500 changes on A arrive complete and in order on B, with cursor paging tested at 1,000 per page and a mid-pull interruption that resumes.
6. **Version conflicts:** a stale `base_version` returns a conflict, never silently overwrites. The client resolves it by the policy and re-pushes (server and client tests).
7. **Offline-first:** each device works fully offline. Sync never blocks the UI, and a failed sync retries with backoff and logs one diagnostics line (PBI-030).
8. Per-device settings stay local; shared settings (language, look, quiet hours…) sync.
9. Remove device revokes its token: its next push or pull gets 401 and it returns to local mode, keeping its data.

## Out of Scope
- Real-time collaborative editing between different people (Family sharing, spec P2).
- Web or desktop clients.
- Field-level merge of free-text (notes): last write wins, with the loser kept in `conflict_log`.

## Grooming Notes (2026-11-10)
- **Field merge for the two exceptions:** when "done wins" or "paid wins" applies, the other changed fields in the losing edit are applied too (title, notes), because they don't contradict completion. Every other conflict is whole-row last-write-wins, as the spec says.
- **Deterministic ids for generated rows:** UUIDv5 over (rule id, period) for ATC payments and tasks, and over (document id, ladder step) for Expiry Guard reminders. This needs a small, tested migration that leaves existing rows' ids unchanged; only newly generated rows use deterministic ids.
- **Server pieces:** the `/sync/push` and `/sync/pull` Edge Functions with RLS. The version check uses a single `update … where version = $base` statement per op inside one transaction per batch.
- **Push channel:** FCM data message "sync now", with no content. Needs a Firebase project created by the product owner (the agent can't create accounts). Without it, the 15-minute poll and resume-time sync still work.
- **Testing:** two `Repositories` instances against one local Supabase in integration tests. A clock-controlled server is used for `updated_at` ordering.
