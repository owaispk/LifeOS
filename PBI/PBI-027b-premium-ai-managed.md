# PBI-027b — Premium AI: Managed Mode (zero-setup) + Lightweight Key Proxy

| Field | Value |
|---|---|
| Epic | E3 ATC / E1 Vault (AI) |
| Priority | P1 (after BYOK proves demand) |
| Story Points | 5 |
| Spec refs | Features §1.2, §15; §14 (privacy) |
| Depends on | PBI-027a (shared pipeline + provider interface), PBI-029 (premium verification) — **not PBI-026** |
| Status | Done (client). Proxy written but never deployed — see below |

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

## Dev & QA Notes (2026-11-10)

No new dependency, and **no schema change** — see the deviation below.

Code:
- `features/ai/platform/managed_provider.dart`: `ManagedProvider` implements the 027a `LlmProvider`, so the gate, consent, cache, badge, fallback and every bit of response hardening are reused untouched.
- `features/ai/ai_providers.dart`: `AiMode`, and a factory that returns one provider or the other — never both, never a fallback between them.
- `features/premium/platform/billing_source.dart`: `entitlementToken()`, which PBI-029 did not expose (see below).
- `server/ai-proxy/`: the Worker, its config and a README stating the contract it must not outgrow.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Unit: a premium user with an entitlement and nothing configured has `mode == managed` and `isConfigured == true`, so the 027a gate reaches `ask`/`send` with no key and no URL. The consent flow, badge and cache are the same code as BYOK. |
| 2 | ⚠️ Client only | Unit: 401 reads as a premium problem, 429 as a daily limit in plain words, 503 as the kill switch — and the on-device result is kept in every case. The proxy's own enforcement is written but has never run. |
| 3 | ⚠️ By code review only | The Worker stores nothing: the only write is an integer counter keyed by a SHA-256 hash of the token with a 48-hour TTL, and every log line is a counter or an error code. Nobody has inspected a real log, because there is no deployment. |
| 4 | ✅ | Unit: in managed mode the only host called is the proxy, with the purchase token as the bearer. With BYOK configured the mode is `byok` and the factory returns the direct provider — a managed call is unreachable from that branch, so a BYOK failure cannot reroute text. |
| 5 | ✅ | The 027a guarantees run again against `ManagedProvider`: text-only payload (no image / base64 / jpeg / png / pdf / `data:`), the same clipping, the same hardened parser dropping wrongly shaped values and unknown fields, prompt injection landing as a plain string, garbage throwing `AiFailure` rather than crashing, and offline behaving like any provider failure. |
| 6 | ✅ | Managed consent says "Our servers forward it to the AI provider and store nothing"; BYOK keeps its own wording. Both EN/UR, picked by mode. |

`flutter analyze`: no issues · full suite `flutter test`: **671/671 passed** (15 new here).

**A gap in PBI-029 this turned up.** 029 modelled entitlement as a boolean and never kept the store's purchase token, which is exactly what the proxy needs to check. `BillingSource.entitlementToken()` was added, `StoreBilling` captures it from the purchase stream, and `PremiumService` persists it to secure storage beside the API key — never the database, never a log line.

**Deviation: the AI mode is derived, not stored.** The groomed description implies a stored mode. It is instead derived — own provider configured means BYOK, otherwise managed — for two reasons. It needs no migration, and PBI-028a had taken schema v13 in the same working tree while this was being built. Switching is still explicit both ways: configuring a provider switches to BYOK, and **Use LifeOS AI instead** clears it. The cost is that a user cannot keep BYOK details saved while preferring managed; a stored mode column is a small follow-up if that turns out to matter.

**This supersedes part of PBI-027a AC5.** "With no provider configured, premium behaves exactly like free" was true when BYOK was the only mode. A premium user with an entitlement now gets managed AI instead — which is the whole point of this PBI. The 027a gate test still passes because it tests the gate directly, but the app-level behaviour has deliberately changed.

**Not verified, and this is the large part:**
- **The proxy has never run.** No JS toolchain in this repository and no Cloudflare account, so the Play entitlement check, the KV counters, the cap, the kill switch and the upstream call are all unexecuted. It is reviewable source awaiting its first deploy.
- The client's managed path has never reached a real proxy; every test uses a fake HTTP client.
- Deploying needs: a Cloudflare account and KV namespace, a model-provider key, and a Play service account to mint `PLAY_ACCESS_TOKEN`. Those are prerequisites, not tasks in this PBI.
- **The prompt now lives in two places** — `extraction_contract.dart` and the Worker — and nothing enforces that they agree. That is the price of server-side prompt fixes without an app release. Worth a check in whatever CI eventually exists.
