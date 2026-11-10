# LifeOS managed AI proxy (PBI-027b)

The entire server side of LifeOS. It exists for one reason: in managed
mode the model-provider key is LifeOS's, and a key cannot sit on a
phone.

## What it must never become

This is **not** the PBI-026 backend, and it must not grow into one.

- **It stores nothing.** No document text, no extraction results, no
  user content. Request and response pass through. The only thing
  written anywhere is an integer call counter, keyed by a SHA-256 hash
  of the entitlement token, expiring after two days.
- **It logs counters and error codes only.** No payloads, no tokens.
- **No accounts, no sessions, no database.** Entitlement is the store's
  purchase token, checked with Google Play on each call.

If a change to this function needs a table, it belongs in PBI-026, not
here.

## Flow

```
phone ──Bearer <play purchase token>──▶ proxy
                                         ├─ kill switch off?        503
                                         ├─ Play says subscribed?   401
                                         ├─ under the daily cap?    429
                                         └─ forward text ──▶ model provider
                                                            │
phone ◀───────────── strict JSON, parsed by the app ────────┘
```

The app parses the reply with the same hardened reader BYOK uses, so a
malformed or hostile answer is handled identically either way.

## Deploy

```bash
npx wrangler kv namespace create COUNTERS   # put the id in wrangler.toml
npx wrangler secret put UPSTREAM_API_KEY
npx wrangler secret put PLAY_ACCESS_TOKEN
npx wrangler deploy
```

Then point the app at it:

```bash
flutter build apk --dart-define=LIFEOS_AI_PROXY=https://<your-worker>/extract
```

## Config, not code

`DAILY_CAP`, `KILL_SWITCH`, `UPSTREAM_MODEL` and `UPSTREAM_BASE_URL` are
all `[vars]`. The kill switch stops every call within one config change,
with no app release — which is the point of it.

## The prompt lives in two places

`SYSTEM_PROMPT` here must stay behaviourally identical to
`systemPrompt` in
`SourceCode/lifeos_app/lib/features/ai/domain/extraction_contract.dart`.
Server-side is what allows a prompt fix without an app release; the cost
is that both copies have to move together. Change one, change the other.

## Status

**Written, never deployed or run.** There is no JS toolchain in this
repository and no Cloudflare account wired up, so nothing here has been
executed — not the Play check, not the counters, not the upstream call.
Treat it as reviewable source awaiting its first deploy.
