# PBI-039 — Personal AI: Ask, Plan and Insights from the User's Own Data

| Field | Value |
|---|---|
| Epic | E7 Personal AI (cross-cutting: Vault, Mind, ATC, Money) |
| Priority | P1 (post-MVP, premium) |
| Story Points | 39 in seven slices (039a–039g); no slice above 8 |
| Spec refs | Features §15 (free/premium split), §14 (privacy); V3 "AI weekly plan" |
| Depends on | PBI-027a (AI pipeline, BYOK), PBI-027b (managed mode), PBI-029 (premium gating), plus per slice below |
| Status | Ready — 039a first |

Today the user's AI key does one job: it re-reads a document when on-device OCR is unsure (PBI-027a). This PBI gives it everyday work. Every feature here passes one test: **a general chat app cannot do it, because the answer depends on data already in LifeOS, or the result has to become a task, payment or bundle that persists.** Features that fail that test (a chatbot tab, standalone message drafting, generic "explain this") are out of scope.

## User Story
As a **premium user with AI connected**, I want LifeOS to answer questions about my own documents, payments and tasks, and to turn messy input into a confirmed plan, so that my AI works on my life and not only on what I paste into a chat.

## Principles (apply to every slice)
- **Proposals only.** AI output never writes a task, payment, category or field by itself. The user confirms through the existing review UI (ATC principle, PBI-027a).
- **Numbers come from the database, never from the model.** Any total, count, date or amount shown is computed on the phone. The model chooses what to look up and phrases the answer.
- **Smallest possible send.** Text snippets and field values relevant to the request only. Never an image, never the whole vault, never the API key.
- **No AI notifications.** Everything appears in-app (PBI-023 holds).
- **Same routes as 027a/027b.** BYOK goes straight to the user's provider; a BYOK failure never falls back to managed.
- **Degrades to nothing.** Offline, not premium, not configured or consent refused: the AI entry points are hidden or locked and every underlying screen works as it does today.
- Neutral by default; all strings EN/UR.

## Slices

### 039a — AI task layer (8 SP) · depends on 027a, 027b, 030
The groundwork the other slices plug into.
- `LlmProvider` gains a general call next to `extract`: a named task with its own versioned prompt, request builder and defensive reply reader. Both `OpenAiCompatProvider` and `ManagedProvider` implement it.
- The gate (`aiGate`) is extended, not bypassed: one decision point still answers premium / configured / consent / online for every task.
- **Per-feature consent.** Each feature has its own switch and a plain "what is sent" line in Settings → AI. First use asks; "Never" for one feature does not affect the others. Existing document-reading consent is unchanged.
- **Usage meter.** Settings → AI shows calls and estimated tokens this month, per feature. Counts only; no content stored.
- **Capability check.** Test connection also records whether the model returns valid structured output. A model that fails is told so plainly and the features that need it are disabled with the reason.
- Cache by task + prompt version + input hash, as in 027a.
- **Managed fair-use cap.** BYOK is never limited by LifeOS. Managed mode has a monthly call cap per subscriber: a proxy-side setting, enforced at the proxy (the app's count is for display only), reset each calendar month. The usage meter shows used / limit. At the limit, AI entry points say "Monthly AI limit reached" with the reset date and a link to "Use my own AI provider"; nothing falls back to another route, and every non-AI behaviour keeps working. Document reading (027a/027b) counts toward the same cap.

### 039b — Ask LifeOS (8 SP) · depends on 039a, 006, 013, 018, 008
- A question box on Home and in Vault search: "When does my passport expire?", "How much did I pay for electricity this year?", "What is my car registration number?".
- Step 1: the model turns the question into one of a fixed set of lookups (document field, document search, payment total by biller/period, expense total by category/period, upcoming expiries, tasks by date). Unknown questions get "I can't answer that from your LifeOS data".
- Step 2: the phone runs the lookup locally (FTS from PBI-006, Drift queries).
- Step 3: the answer is shown with its **sources** (tappable documents, payments or tasks). For document questions, the top matching snippets are sent for phrasing; for totals, only the computed figure is.

### 039c — Brain dump to plan (5 SP) · depends on 039a, 010, 034, 013
- In the add sheet and in share-in: a paragraph of free text (typed, dictated or shared from another app) becomes a list of proposed tasks, dates and payments.
- One review screen: each proposal editable, removable, and individually confirmed or "Add all".
- The on-device parser (PBI-010) still runs first and remains the result when AI is unavailable.

### 039d — Weekly brief (5 SP) · depends on 039a, 011, 019, 032, 008
- A Home card on the user's week-start day (and on demand): bills due, documents expiring, calendar load and overdue tasks for the coming week, in a short plain summary.
- When a day is over the Overload Shield limit, the brief proposes specific tasks to move, each with a one-tap accept.
- The facts list is built on the phone; the model orders and words it. With AI unavailable the card shows the plain facts list.

### 039e — Money insights (5 SP) · depends on 039a, 014, 018, 019
- **Categorise:** uncategorised expenses get a proposed category from the user's existing category list; accept one or all.
- **Unusual bill:** computed on the phone from that biller's history (no AI needed to detect it); the model adds a one-line explanation only when the bill's text gives a reason.
- **Recurring charges:** expenses that repeat monthly without an ATC rule are proposed as rules.

### 039f — Renewal checklist with documents (5 SP) · depends on 039a, 008, 028a, 009
- From an expiring document or a task such as "Renew passport": a proposed checklist of steps and a list of documents typically required.
- Each required document is matched against the vault: found, **missing**, or **expired**. Found ones are offered as a ready bundle (PBI-028a).
- The checklist is general guidance and labelled as such ("Check the official requirements"); no country or authority is assumed unless the document itself states it.

### 039g — Document actions (3 SP) · depends on 039a, 007, 009, 013
- A button in the document viewer: "Find what I need to do". Returns deadlines, amounts due and required actions found in the document's text as proposed tasks and payments.
- A short plain-language summary is shown above the proposals, in the app language.

## Acceptance Criteria
1. **Gate:** for every new task, a call happens only when premium, configured, online and that feature's consent allow it; the "exactly one allowing state" test from 027a covers the new tasks. (039a)
2. **Consent is per feature:** refusing one feature leaves the others and document reading unaffected; each feature's "what is sent" text matches its request builder (asserted in tests). (039a)
3. **Nothing sensitive leaves:** no request body in any slice contains image bytes, the API key, or rows unrelated to the request (request-builder tests per task). (all)
4. **Usage meter** increments once per real call, not on cache hits, and stores no content. (039a)
5. **Capability check:** a model that cannot return valid structured output is reported at Test connection, and dependent features show as unavailable with the reason. (039a)
6. **Ask LifeOS totals are local:** for a seeded database, the amount shown equals the Drift query result even when the fake model returns a different number. (039b)
7. **Ask LifeOS cites sources:** every answer lists at least one tappable source, or says it cannot answer; a question outside the fixed lookups never produces an invented answer. (039b)
8. **Brain dump:** a paragraph with three actions yields three editable proposals; nothing is saved until confirmed; with AI unavailable the PBI-010 parser result is used. (039c)
9. **Weekly brief:** the card's facts match the on-device data for the coming week; an accepted "move" suggestion reschedules exactly that task; no notification is scheduled. (039d)
10. **Money insights:** proposed categories come only from the user's existing list; the unusual-bill flag is identical with AI on and off; a proposed recurring rule is created only on accept. (039e)
11. **Renewal checklist:** required documents are marked found / missing / expired against a seeded vault; the bundle contains only found, unexpired documents. (039f)
12. **Document actions:** proposals carry shape-checked dates and amounts (same validators as 027a); a malformed or hostile reply writes nothing. (039g)
13. **Malformed replies** (empty, prose, wrong types, prompt-injection text) never crash, never write data and fall back to the non-AI behaviour, for every task (fuzz tests). (all)
14. **Tiers and offline:** free users see locked entry points with the upgrade pitch; offline or unconfigured, every screen behaves as it does today. All strings EN/UR; neutrality test passes. (all)
15. **Managed cap:** in BYOK mode no LifeOS limit is ever applied. In managed mode, a proxy "limit reached" reply shows the limit message with the reset date and the BYOK link, makes no further calls until reset, never switches route, and leaves the non-AI result in place; cache hits do not count toward the cap. (039a)

## Grooming Notes
- **Build order:** 039a → 039b → 039c → 039d → 039e → 039f → 039g. 039b is the flagship and the one to demo.
- **Decided 2026-11-12 — managed quota.** BYOK calls cost LifeOS nothing; managed calls do. So BYOK is unlimited and managed mode runs under a monthly fair-use cap (see 039a, AC15). The cap's number is still to be set, from real per-call cost once the proxy is deployed.
- **Precondition:** 027a still has no live round-trip against a real provider. Do that on a phone before starting 039a.
- **Lookups are a closed list** in 039b on purpose: it keeps the model from composing queries, makes answers testable, and limits what a hostile document or question can reach.
- Prompts are versioned in-repo, one per task, like the 027a extraction prompt.
- **Out of scope:** a general chat tab, standalone message drafting, image input to the model (Urdu/handwriting — separate PBI, changes the "never the image" promise), any AI-triggered notification, AI acting without confirmation.
