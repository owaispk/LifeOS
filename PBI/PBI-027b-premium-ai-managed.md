# PBI-027b — Premium AI: Managed Mode (zero-setup) + Lightweight Key Proxy

| Field | Value |
|---|---|
| Epic | E3 ATC / E1 Vault (AI) |
| Priority | P1 (after BYOK proves demand) |
| Story Points | 5 |
| Spec refs | Features §1.2, §15; §14 (privacy) |
| Depends on | PBI-027a (shared pipeline + provider interface), PBI-029 (premium verification) — **not PBI-026** |
| Status | Ready (blocked by 027a) |

Makes premium AI zero-setup for mainstream users: LifeOS's own API key pays for the calls, so the key must live server-side. This PBI includes a deliberately tiny, **stateless** proxy — it is *not* the PBI-026 backend (no auth system, no sync, no stored data) and must not grow into one.

## User Story
As a **premium user who will never create an API key**, I want AI document extraction to just work out of the box.

## Description

### Lightweight proxy (the only server piece)
- One stateless Edge Function (Supabase or Cloudflare Workers free tier): verify premium entitlement token (PBI-029, e.g. Play purchase token) → check per-user daily cap and global kill switch (config flags) → forward the text to the LLM provider (budget tier, e.g. Gemini Flash-Lite) → return the JSON.
- **Stores nothing.** No document text, no results, no user content — request/response pass through only. Logs are counters and error codes, never payloads.
- Per-user daily call cap and a global kill switch protect the API bill; the client treats a 429/disabled response like any provider failure (on-device fallback, friendly message).
- Prompt lives server-side here (enables prompt caching discounts and silent prompt fixes without an app release); kept byte-identical in behaviour to the in-repo prompt used by BYOK.

### Client side
- `ManagedProvider` implements the existing `LlmProvider` interface from 027a — the gate, consent flow, cache, badge, fallback and fuzz-hardening are all reused untouched.
- **Managed is the default for premium**; BYOK remains the Advanced override. Switching modes is explicit — a BYOK failure never silently reroutes text to the managed proxy (that would move data without consent).
- Consent dialog and privacy screen name the destination accurately for this mode: "LifeOS AI (our servers forward your text to the AI provider and store nothing)."

## Acceptance Criteria
1. A premium user with zero configuration gets AI extraction on a low-confidence document (consent flow included), with the "AI-read" badge — no key, no URL, no setup.
2. The proxy rejects calls without a valid premium entitlement (401) and over the daily cap (429); the client shows a friendly limit message and keeps the on-device result. The kill switch stops all calls within one config change, no app release.
3. The proxy stores no document text or extraction results (code review + log inspection as evidence); its logs contain counters and error codes only.
4. With BYOK configured, no call ever reaches the managed proxy; with managed active, no call goes anywhere but the proxy (host assertions in tests for both modes).
5. All 027a guarantees still pass unchanged against `ManagedProvider`: gate, text-only payload, hash cache, consent persistence, malformed-response fuzzing, offline behaviour (the shared suite runs against both providers).
6. Managed-mode consent and privacy copy name LifeOS servers as a pass-through; EN/UR.

## Grooming Notes
- Proxy ~50–100 lines; deploy config (anon rate limits, cap values, kill switch, model name) in environment/config, not code. Start on the provider's free tier — expected cost at launch volumes is effectively zero (see cost model: ~$0.0003/doc at budget-tier pricing).
- Entitlement verification: whatever PBI-029 lands (Play Billing purchase-token check is sufficient; a full account system is explicitly not required).
- Abuse surface: without auth accounts, rate-limit by entitlement token + coarse IP; acceptable for the cost ceiling given caps + kill switch.
- Revisit placement when PBI-026 (real backend) lands — the function can move house, but its statelessness contract stays.
