# PBI-039a — Daily Voice Brief: Personal AI Assistant Briefing

| Field | Value |
|---|---|
| Epic | E7 Personal AI (voice layer: Vault, Mind, ATC, Money) |
| Priority | P1 (post-MVP, premium; flagship slice of 039) |
| Story Points | 10 |
| Spec refs | PBI-039 (Personal AI), PBI-023 (notification diet), Features §14 (privacy); V3 "AI weekly plan" |
| Depends on | PBI-027a (AI pipeline BYOK), PBI-027b (managed mode), PBI-029 (premium gating), PBI-020 (Life Score), PBI-008 (Expiry Guard), PBI-011 (Overload Shield), PBI-019 (Money forecast), PBI-012 (notifications) |
| Blocked by | First live 027a/027b round-trip against a real provider (on a phone) |
| Status | Ready — platform for all downstream 039 slices (039b–039g) |

## User Story

As a **busy parent, student or professional with AI enabled**, I want LifeOS to speak a personalized morning or on-demand life update (tasks, bills due, expiring documents, spending summary) so I can absorb my day in 30 seconds while getting ready, without touching my phone.

## Description

**Daily Voice Brief** is the foundation layer for all Personal AI work (PBI-039). It:

1. **Grounds AI in real data.** Every number, date and fact comes from the database; the LLM only chooses what to look up and phrases the answer naturally.
2. **Speaks the user's life.** Urdu + English voice, covers all four domains (tasks, money, vault, payments), tone matches the user's Life Score band (triage under 40, steady state otherwise).
3. **One call, many uses.** Builds an LLM task infrastructure (request builder, reply parsing, caching, consent, usage meter) reusable by 039b–039g without duplication.
4. **Works offline with graceful fallback.** Scheduled or on-demand: if AI unavailable, shows a plain-text version; if AI enabled, delivers natural language.
5. **Respects privacy, attention and premium.** Zero cloud storage, per-feature consent, usage meter, BYOK unlimited + managed cap, quiet-hours aware, visible only to premium users.

## Acceptance Criteria

### Gate & Consent (AC 1–4)
1. **Premium + configured gate:** A scheduled brief fires only if user is premium, AI is configured, the device is online, and "Daily Brief" consent is enabled. Free users see the brief button locked with upgrade pitch. Offline or unconfigured users see the same screen, but tapping "get brief now" shows "Connect AI to continue" instead of error.
2. **Per-feature consent.** Daily Brief has its own toggle in Settings → AI, separate from document reading (PBI-027a). First use prompts: "Read your daily summary in natural language?" + "What is sent: today's task count, due payments, expiring docs, spending total, Life Score — no content." Opt-in or "Never".
3. **Settings → AI → Manage features.** Shows Daily Brief, Ask LifeOS (039b), Brain Dump (039c), etc., each with its own on/off + "What is sent" tooltip + learn more link.
4. **Capability check.** At Test connection (Settings → AI → Test), the LLM is asked to structure a fake brief. If it fails (returns prose, wrong fields, empty), the brief is marked "Unavailable — this model cannot format structured replies" and the button is locked. The test result is saved and checked at brief time.

### Data & Request (AC 5–7)
5. **Local computation only.** The brief's facts come entirely from the database: task count due today, overdue payment count, expiring doc count (30-day window), spending today/this-month, Life Score band. The request to the LLM contains only these seven structured fields and their values, never task titles, bill amounts, document names or images. Test with a seeded database: the plain-text fallback (AC9) and AI output must agree on counts and totals.
6. **Request builder is versioned.** `lib/features/ai/domain/prompts/daily_brief_v1.txt` (or similar) contains the exact system prompt and user request template, checked into version control. The request builder reads it, injects the seven fields, and builds a JSON request. Request-builder tests assert the request contains no sensitive data.
7. **Smallest possible send.** The request is: `{ "task_count": 4, "overdue_payments": 1, "expiring_docs": 2, "spent_today": 3500, "spent_this_month": 45000, "monthly_budget": 85000, "life_score": 78, "life_score_band": "steady" }` (JSON, ~200 bytes). No images, no API key, no unrelated database rows, never the user's name.

### LLM Integration (AC 8–11)
8. **Same gate as 027a/027b.** Both `OpenAiCompatProvider` (BYOK) and `ManagedProvider` implement a general `call` method alongside the existing `extract`. The gate (`aiGate`) checks premium / configured / online / consent once per request. A BYOK failure never falls back to managed.
9. **Structured reply parsing.** The model returns JSON: `{ "brief": "Good morning. You have 4 tasks today...", "tone": "steady" }` (text field + tone enum: "triage" under 40, "steady" 40–70, "excellent" 70+). A malformed reply (missing fields, prose, null values, hostile injection) does not crash; the app falls back to plain-text (AC9). Tests: valid reply, missing field, prose, empty string, injection attempt.
10. **Cache by task + request hash.** If the same request hash is seen twice in the same calendar day (e.g., user taps brief twice), return the cached reply. Cache is cleared at midnight. Cache hits do not count toward usage meter or monthly cap.
11. **Managed fair-use cap.** BYOK mode (user's own key) has no LifeOS-side limit. Managed mode calls are subject to a monthly cap per subscriber, enforced at the proxy. The app shows "Used X / Y calls this month" in Settings → AI (display only). When the cap is reached, the proxy returns `{ "error": "monthly_cap_reached", "reset_date": "2026-12-13" }`, the brief shows "Monthly AI limit reached. Resets December 13. Use your own AI key to continue." (with a link to BYOK setup), and the app does not retry or fall back to a different route. Non-AI brief (AC9) remains accessible.

### Voice & Notifications (AC 12–14)
12. **Text-to-speech (TTS).** Use Flutter `flutter_tts` package (or platform equivalents for iOS) to speak the brief's text. Voices: English (default system), Urdu (if available on device; falls back to English). User taps "Speak" button after receiving brief text. If TTS fails, text remains readable. Rate adjustable in Settings (0.8–1.2 of normal).
13. **Scheduled briefing.** A notification at `brief_time` (default 07:30, user configurable) wakes the app. If premium + configured + online, the app fetches the brief in the background and shows a notification: "☀️ Your life update is ready. Tap to listen." Tapping opens a fullscreen brief card with Speak button. The scheduled notification is stable (id: "daily_brief"), so changing the time reschedules it. Quiet hours (PBI-023): the notification is deferred to the end of quiet hours if `brief_time` falls inside them (same logic as digest).
14. **On-demand brief.** Home and in Settings → AI, a "Get your brief now" button. Tapping shows a loading state, fetches the brief (or returns cached if within the same day), and shows the card with Speak button. If offline or unconfigured, shows the gate message instead. If managed mode is at cap, shows the cap-reached message.

### Usage Meter & Transparency (AC 15–17)
15. **Usage meter stores only counts.** Settings → AI shows: "Daily Brief: 4 calls this month / 50 available" (for managed) or "Daily Brief: 8 calls (unlimited)" (for BYOK). Stores only call count, date, and whether it hit the cap. No request body, no response text, no user data is ever logged.
16. **Meter is per-feature.** Each 039 slice (Brief, Ask LifeOS, etc.) has its own counter. Document reading (PBI-027a/027b) has a separate counter. All count toward the same monthly cap in managed mode.
17. **Offline and free-tier degradation.** Offline: brief button shows "Offline — text brief available". Free user: button locked with "Premium feature — upgrade to enable AI." Clicking it opens the upgrade screen. No error is ever shown; the UI is always clear about why the feature is unavailable.

### Fallback & Robustness (AC 18–20)
18. **Plain-text fallback.** When AI is unavailable (offline, unconfigured, consent off, or model failure), the app shows a formatted text brief with the same data: "☀️ Your life today: 4 tasks, 1 payment due, 2 docs expiring in 30 days. Spent ₹3,500 so far this month (budget: ₹85,000). Life Score: 78 — doing well." Tone and formatting match the Life Score band (triage vs. steady vs. excellent), no special model needed.
19. **Timeout & retry.** If the LLM call takes > 15 seconds or returns an error (network, provider down, quota exceeded), show the plain-text fallback immediately and log (to diagnostics). Do not show "error" to the user; the plain-text brief is always graceful.
20. **Malformed replies never crash.** Fuzz tests: missing `brief` field, `brief` is null or integer, `tone` is invalid enum, response is empty JSON `{}`, response is hostile injection like `"brief": "{{ delete_user() }}"`. Each case falls back to plain-text and logs the issue. No exception escapes to the UI.

### Localization & Accessibility (AC 21–23)
21. **Urdu + English.** The brief text and tone labels are localized. Settings → Language controls it. System prompt and request are in English (model sees the data clearly); the reply is always in the user's chosen language (via a prompt prefix: "Respond in [Urdu|English]").
22. **Tone matches Life Score band:** Below 40 (red): triage mode, e.g., "Heavy week ahead. Focus on: pay electricity, renew CNIC, 2 other high-impact items." 40–70 (amber): steady, "You have 4 tasks and 1 bill due. Spending is on track." 70+ (green): excellent, "Great week ahead! Just 1 task and nothing urgent." The plain-text fallback also follows this tone.
23. **Screen reader & accessibility.** Brief card is an accessible dialog. Speak button has label "Speak brief aloud (30 seconds)". If TTS is unavailable, the button is hidden (text is enough). Time displayed: "Brief from 07:30 this morning" or "Just now" (on-demand).

### Testing (AC 24–26)
24. **Unit tests:** Request builder never includes sensitive data (test against a checklist: task titles, doc names, amounts, images, keys). Cache logic (same day vs. next day, hits vs. misses). Plain-text fallback matches database totals in 5+ scenarios. Malformed reply handling (20+ fuzz cases).
25. **Widget tests:** Scheduled brief fires at the right time (mock SystemClock). On-demand brief loading state, success, failure, offline, free-tier states all render correctly. Speak button is present, tap triggers TTS.
26. **Integration test (once 027a/027b deployed):** End-to-end with a real LLM provider (or mock): premium user, scheduled brief at 07:30, calls the LLM, shows natural language reply in the UI, usage meter increments. Managed cap enforcement: cap reached → shows the cap message and does not call the LLM again that month.

## Grooming Notes

### Build Order for 039a
1. **LLM infrastructure (LlmProvider.call, managed + BYOK)** — shared by all 039 slices.
2. **Request builder + response parser** — version-pinned prompt, field extraction, malformed-reply handling.
3. **Consent UI** — per-feature toggle in Settings, first-use prompt, "What is sent" tooltip.
4. **Usage meter** — call counter, monthly cap logic, UI display.
5. **Scheduled briefing** — notification at brief_time, quiet-hours aware, reschedule on setting change.
6. **On-demand + plain-text fallback** — Home/Settings button, loading states, offline/free-tier gates, TTS.
7. **Tests & QA** — all 26 ACs.

### Cascade to 039b–g
039b (Ask LifeOS), 039c (Brain Dump), 039d (Weekly Brief), 039e (Money Insights), 039f (Renewal Checklist), 039g (Document Actions) all depend on 039a for:
- The LLM gate & consent framework
- Request/response builder templates
- Usage meter infrastructure
- Managed cap enforcement
- Fallback patterns (each has its own non-AI version already or a sensible degradation)

They add their own prompts, request builders, and feature-specific toggles, but no slice repeats the gate/meter/cap logic.

### Key Decisions (2026-11-13)

**LLM choice & deployment:** Must be decided *before* starting dev:
- **Option A: Local on-device (offline-first, lowest privacy, limited quality)**
  - Use a lightweight local model (e.g., Ollama, on-device Llama).
  - Works fully offline; zero network call.
  - Much slower (5–10 sec for reply) and smaller model = less natural language.
  - Good for early testing; likely insufficient for long-term UX (Urdu support weak).
  
- **Option B: Cloud BYOK + Managed fallback (production-ready, user-controlled cost)**
  - User supplies their own OpenAI/Anthropic/etc. key → calls their account directly.
  - Managed mode: proxy at `https://ai.lifeos.app/brief` (or similar) calls Anthropic (or chosen provider) and bills LifeOS's account.
  - Managed calls are capped at ~50–100 per user per month (exact number set after first 027a/027b bill).
  - BYOK is unlimited and free for LifeOS.
  - Requires the proxy to be deployed (PBI-027b infrastructure exists but is undeployed).

- **Option C: Hybrid (best UX, most complex)**
  - Try local first; on failure or slow response, fall back to cloud.
  - Adds complexity and testing burden.

**Recommendation:** Start with **Option B (cloud BYOK + managed)** because:
- Urdu TTS + LLM support is much better in cloud (OpenAI Turbo, Anthropic Claude).
- Brief is *premium* (user expects cloud), so the architecture is aligned.
- 027a/027b already use this pattern; reuse the same gate & providers.
- PBI-026c (multi-device sync) will need the server anyway; the proxy is a stepping stone.

**Decision point:** This PBI is Ready to groom once the 027a/027b proxy is deployed and tested live on a phone with a real provider. Until then, the PBI can be tech-spec'd and mocked but dev is blocked.

### Rollout Notes

- **Free tier:** Brief button locked; upgrade pitch visible.
- **Premium, no AI configured:** Brief button shows "Connect AI" → Settings → AI.
- **Premium, configured, managed mode:** Brief fires on schedule, shows usage "X / 50 this month".
- **Premium, configured, BYOK:** Brief fires on schedule, shows "Unlimited".
- **Quiet hours:** Scheduled brief deferred to end-of-window (same as digest, PBI-023).
- **Notification digest (PBI-023) vs. Voice Brief:** They are independent. User can have both or just one. Digest is on the digest at 07:30; brief is on brief_time (default 07:30 but can differ). If both are at 07:30, the app sends both—no dedup needed (they target different media: text notification vs. voice).

## Dev & QA Notes (TBD — Start after 027a/027b deployed)

Code structure (parallel to PBI-027a/b):
```
lib/features/ai/
  ├── domain/
  │   ├── llm_provider.dart          // interface: call() + extract()
  │   ├── prompts/
  │   │   ├── daily_brief_v1.txt      // system prompt + user template
  │   │   └── extraction_v2.txt       // re-used from 027a
  │   ├── daily_brief_usecase.dart    // computes brief data, builds request
  │   └── usage_meter.dart            // call counts, cap logic (pure)
  ├── data/
  │   ├── openai_provider.dart        // BYOK (re-used from 027a)
  │   ├── managed_provider.dart       // cloud proxy (re-used from 027a)
  │   └── daily_brief_repo.dart       // cache, meter storage
  └── presentation/
      ├── providers.dart              // Riverpod: aiGate, usageMeter, brief
      ├── screens/
      │   └── brief_screen.dart       // fullscreen brief card + speak
      └── widgets/
          ├── brief_button.dart       // Home + Settings
          └── speak_button.dart       // TTS trigger

lib/features/settings/
  └── ai/
      ├── ai_settings_screen.dart     // features on/off, test connection
      └── consent_prompt.dart         // first-use "what is sent"
```

**Notification:** Reuses `ReminderSync` (from PBI-023). Add a brief reminder kind with stable id and gate-aware scheduling.

**Integration test setup (once 027a/027b live):**
- Mock LLM provider returns known JSON.
- Seeded database: 4 tasks, 1 overdue payment, 2 expiring docs, Life Score 78.
- Call `getDailyBrief()` → assert counts match database.
- Cache test: second call same day returns cached.
- Third call next day calls LLM again.
- Managed cap: mock proxy returning cap-reached error → brief shows cap message.

## Spec Alignment

- **Features guide §14 (Privacy):** Brief never stores request or response. Plain-text fallback is always available offline.
- **Features §12 (Attention):** One AI call per day (or on-demand cache); no spammy notifications. Quiet hours respected.
- **Features §15 (Free/Premium):** Brief is premium-only; free users see locked UI.
- **Neutral by default:** Tone and language are culturally neutral; Urdu support same as English.

## Dependencies & Blockers

| Depends on | Status | Impact if delayed |
|---|---|---|
| PBI-027a (BYOK) | Done | None (interface exists; gate pattern reusable) |
| PBI-027b (managed) | Done (proxy undeployed) | **Blocks dev.** PBI-039a can be tech-spec'd offline but cannot be tested end-to-end until 027b is deployed to a live provider. |
| PBI-029 (premium gating) | Done | None (gate reusable) |
| PBI-020 (Life Score) | Done | None (brief reads the snapshot) |
| PBI-008 (Expiry Guard) | Done | None (brief reads expiring docs count) |
| PBI-023 (Notification diet) | Done | None (scheduled brief hooks into ReminderSync) |

**Critical blocker:** First live round-trip of 027a/027b against a real provider on a phone must complete before 039a dev starts. This is the Precondition from PBI-039.

## Acceptance Criteria Checklist

| AC | Title | Ready for Dev |
|---|---|---|
| 1–4 | Gate, consent, capability check | ✅ Yes (reuse 027a pattern) |
| 5–7 | Data, request, no sensitive data | ✅ Yes (define schema + tests) |
| 8–11 | LLM integration, cache, cap | ✅ Yes (refactor 027a, define prompts) |
| 12–14 | Voice, notifications, on-demand | ✅ Yes (TTS package available, scheduler logic in PBI-023) |
| 15–17 | Usage meter, transparency | ✅ Yes (define schema, UI) |
| 18–20 | Fallback, timeout, malformed | ✅ Yes (define plain-text format, tests) |
| 21–23 | Localization, tone, a11y | ✅ Yes (localize plain-text, TTS a11y patterns known) |
| 24–26 | Tests, widgets, integration | ✅ Yes (can be written without live provider; mocked for now) |

---

**Status:** Ready to groom. Tech spike: confirm 027a/027b deployed with live provider round-trip. Start dev after spike.
