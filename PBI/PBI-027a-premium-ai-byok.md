# PBI-027a — Premium AI: Bring-Your-Own-Key (no backend)

| Field | Value |
|---|---|
| Epic | E3 ATC / E1 Vault (AI) |
| Priority | P0 (post-MVP, premium) |
| Story Points | 5 |
| Spec refs | Features §1.2 (classification), §15 (free/premium split), §14 (privacy) |
| Depends on | PBI-004 (OCR pipeline + confidence), PBI-024 (secure storage, app lock), PBI-029 (premium gating) — **no backend, no PBI-026** |
| Status | Done — device QA and a real provider run pending |

Ships first. Carries the shared AI pipeline (gate, consent, cache, provider interface) that PBI-027b later plugs into. Zero LifeOS infrastructure and zero LifeOS API cost: calls go directly from the device to the user's own AI provider.

## User Story
As a **premium user**, when on-device OCR can't read a document (bad photo, Urdu script, odd layout), I want to connect my own AI provider so LifeOS extracts it — directly from my phone to my AI account, with LifeOS servers never involved.

## Description

### Shared AI pipeline (built here, reused by 027b)
- The on-device pipeline (ML Kit + rules + templates) stays the default for everyone and always runs first.
- Cloud AI fires **only** when on-device classification confidence is below a threshold, only for premium users with a configured provider, and only with consent.
- **Text only, never the image:** the call sends extracted OCR text (plus field hints), never the photo/PDF. Response is strict JSON (doc type, dates, amounts, reference numbers); capped output tokens.
- Results cached by document text hash — the same document is never sent twice. A successful extraction feeds the ATC template store (PBI-014), so future bills from that vendor are free again.
- A garbage/malformed AI response falls back to the on-device result silently; the pipeline never throws.
- `LlmProvider` interface: `extract(text, hints) → ExtractionResult`. This PBI implements `OpenAiCompatProvider` (baseUrl/apiKey/model); 027b adds `ManagedProvider` behind the same interface.

### BYOK configuration
- Settings → AI → "Use my own AI provider": base URL + API key + model, with one-tap presets for common OpenAI-compatible providers and a custom/local option (e.g. a home Ollama server — fully private AI).
- **Test connection** button makes one tiny call on save and surfaces the provider's real error message.
- Runtime provider errors show the provider's message ("quota exceeded"), then the document keeps its on-device result. There is no managed fallback yet (027b).
- UI states the privacy win plainly: "Your document text goes directly to your AI provider. LifeOS servers never see it."

### Access & gating
- **Free users:** the Settings → AI section is **visible but locked** (🔒) — benefits pitch ("reads damaged photos, Urdu documents, learns new billers") + Upgrade button. Deliberate in-app marketing.
- When a free user's document lands below the confidence threshold, the document detail shows one **inline, dismissible** teaser: "Premium AI could read this document." Inline only — never a notification (PBI-023 holds); dismissing suppresses it for that document forever.
- **Opening or editing AI settings requires re-auth** (biometric/PIN, same as changing App Lock) — pointing the app at a hostile endpoint is a data-exfiltration path.
- Family sharing (V2): only the plan owner sees or edits provider settings.

### Consent & privacy
- Per-document consent the first time, remembered after: "Couldn't read this fully on the phone. Send the text (not the image) to your AI provider?" — Always / Just this once / Never.
- API key lives in `flutter_secure_storage` only — never in the Drift DB, the export ZIP (PBI-025), or logs. The PBI-030 scrubber gains explicit masking for API-key patterns (`sk-…`, `AIza…`, long base64/hex runs).
- Privacy screen states exactly what is sent (text, not images) and where (the user's own provider).

## Acceptance Criteria
1. A document that classifies confidently on-device never triggers a cloud call, for any tier (gate unit test).
2. Low confidence + premium + provider configured + consent: the call sends OCR text only (no image bytes — asserted in the request-builder test) directly to the configured base URL (no other host contacted), and the document gets extracted fields with an "AI-read" badge.
3. The same text hash never produces a second call (cache test).
4. Free tier: AI settings visible, locked, with the upgrade pitch; the inline teaser is dismissible, never reappears for that document, and no AI notification of any kind is ever scheduled.
5. Test connection shows the provider's real error on a bad key/URL; a runtime provider failure shows the provider's message and the document keeps its on-device result; with no provider configured, premium behaves exactly like free (no calls, no errors).
6. Opening AI settings prompts re-auth when App Lock is on. The API key is absent from the database file, the export ZIP, and diagnostics logs (scrubber test includes key patterns).
7. Consent "Never" stops all cloud calls until changed in Settings; "Just this once" does not persist.
8. Malformed/garbage AI responses (invalid JSON, wrong fields, prompt-injection text) never crash, never write bad fields, and fall back to the on-device result (fuzz tests).
9. All new strings EN/UR; everything except the cloud call works offline; with no connectivity the pipeline behaves exactly as free tier.

## Grooming Notes
- The OpenAI-compatible chat API covers OpenAI, Gemini-compat, Groq, DeepSeek, OpenRouter, Mistral, Ollama and LM Studio — one HTTP client serves every preset; presets are prefilled baseUrl+model.
- Confidence gate lives where PBI-004 computes classification confidence; threshold is a constant with a hidden testing override.
- One system prompt + few-shot examples, versioned in-repo like `score_weights.json`; strict JSON schema requested, response parsed defensively (first JSON block, every field validated). Document text in a delimited block; extracted fields are *proposals* through the existing ATC review UI — nothing auto-executes from AI output (prompt-injection containment, ATC principle).
- Out of scope: managed mode (027b), AI weekly plan, cloud *image* OCR for Urdu (follow-up PBI — this is text-in/JSON-out), expense categorisation.

## Dev & QA Notes (2026-11-10)

New dependency: `http`. Schema v12 adds `ai_base_url`, `ai_model`, `ai_consent` — and deliberately **no** column for the key.

Code, under `lib/features/ai/`:
- `domain/ai_gate.dart` (pure): `aiGate()` is the one decision point. Every condition — confident, no text, not premium, not configured, refused, ask, send — is answered there, and `gateAllowsCall` is true for exactly one of them. A test asserts that, so a later edit cannot quietly open a second route to the network.
- `domain/extraction_contract.dart` (pure): the prompt (built from the type and field lists, so it cannot drift from what the parser accepts), the request body, and a defensive reader for the reply.
- `platform/llm_provider.dart`: `LlmProvider` with `OpenAiCompatProvider`. 027b plugs `ManagedProvider` in behind the same interface.
- `platform/secret_store.dart`: the key, in the Keystore/Keychain only.
- `ai_providers.dart`: settings, the enrichment service and its cache, and `mergeAiFields`.
- `ui/ai_settings_screen.dart`, `ui/ai_card.dart`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Unit: a confident classification returns `AiGate.confident` for premium and free alike, and even with consent already given and a provider configured. The gate is checked before anything else. |
| 2 | ✅ | Unit: the request carries the document text and the body contains none of image / image_url / base64 / jpeg / png / pdf / `data:`. The call goes to the configured host and path, with the key as a bearer token; a provider with no key sends no `authorization` header at all. |
| 3 | ✅ | Unit on the cache key: the same text hashes the same (whitespace-insensitive), different text does not. The key includes the prompt version, so changing the prompt does not serve stale answers. |
| 4 | ✅ | Unit: free tier returns `AiGate.notPremium` and `gateAllowsCall` is false. The teaser is a card in the confirm step with a dismiss button; nothing in this feature schedules a notification of any kind. |
| 5 | ✅ | Unit: the provider's own message is passed through unchanged ("You exceeded your current quota.", with its 429); a non-JSON error body still yields something useful; premium with no provider configured returns `AiGate.notConfigured`, which permits no call. |
| 6 | ✅ | A real storage test writes a key through the service, then reads **every** value in `user_settings`, `app_meta` and `documents` and asserts the key appears in none — while also asserting the base URL and model *did* save, so it cannot pass by writing nothing. Plus: no settings column is named like a secret, and the scrubber masks `sk-…`, `AIza…`, `Bearer …` and long mixed-case tokens. |
| 7 | ✅ | Unit: `never` returns `AiGate.refused`. "Just this once" calls `runAi` without writing consent; "Always" writes it first. |
| 8 | ✅ | Unit over malformed replies: empty, prose, `{`, `[]`, `null`, wrong types, nested objects — none throw, none produce fields. An unknown type falls back to `other`; fields we did not ask for are dropped; a wrongly shaped value ("Rs 4,850" as an amount, "14/11/2026" as a date, "2026-02-31") is dropped rather than stored. Prompt-injection text lands as a plain string in a form field and executes nothing. |
| 9 | ✅ | All strings EN/UR. With no connectivity the call throws, the card shows the provider's message, and the document keeps its on-device result — the same outcome as free tier. |

`flutter analyze`: no issues · full suite `flutter test`: **648/648 passed** (29 new).

**Design notes:**
- **AI values are proposals that fill gaps only.** `mergeAiFields` never overwrites a value the phone read or the user typed. Combined with every value being shape-checked on the way in, a hostile document cannot change a field that was already known.
- **The badge cannot be faked.** An AI-filled field carries a sentinel confidence of `-1`, distinct from any on-device score, so "AI-read" means exactly that.
- **The key is write-only in the UI.** The stored key is never put back into the field; the form says "Saved on this phone only" instead.

**One deviation:** the free-tier teaser lives in the **confirm step**, not the document detail screen, because that is where a low-confidence read actually happens — the document does not exist yet at that point. Dismissal therefore lasts for that capture, not forever for a saved document. Moving it to document detail (and persisting the dismissal per document id) is a small follow-up if the original placement is wanted.

**Not verified:** no call has been made to a real provider. Every test uses a fake HTTP client, so the request shape, the error passthrough and the parser are proven, but a live round-trip against OpenAI, Groq or a local Ollama has not happened. That plus the re-auth prompt and the Keystore write need a phone, and should join the device QA session.
