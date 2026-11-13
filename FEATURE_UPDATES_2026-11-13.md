# LifeOS — Feature Updates (2026-11-13)

## Summary

Two new PBIs were created to boost **daily user retention** and align with your Personal AI roadmap:

1. **PBI-039a: Daily Voice Brief** (Post-MVP, Premium, 10 SP) — Voice Agent as the morning life update
2. **PBI-026: Quick Capture Inbox** (MVP+1, 8 SP) — Frictionless "dump anything" entry point

---

## 1. PBI-039a — Daily Voice Brief: Personal AI Assistant Briefing

**File:** `PBI/PBI-039a-daily-voice-brief.md`

### What It Does
A personalized voice agent that reads your morning life update in 30 seconds:
- *"Good morning. You have 4 tasks today. 1 payment is due, 2 documents expire in 30 days. You've spent ₹3,500 this month against a ₹85,000 budget. Life Score: 78 — doing well."*

### Key Features
- ✅ **Scheduled briefing** at 07:30 (configurable), respects quiet hours
- ✅ **On-demand access** via Home or Settings button
- ✅ **Text-to-speech** in English & Urdu, rate-adjustable
- ✅ **Plain-text fallback** when AI is unavailable (always graceful)
- ✅ **All data stays local** — only 7 fields sent to LLM (task count, due payments, expiring docs, spending, Life Score, etc.)
- ✅ **Usage meter** — shows calls used, monthly cap, per-feature transparency
- ✅ **Per-feature consent** — user controls what data each AI feature can access
- ✅ **Premium + managed cap** — BYOK (unlimited) or managed cloud with fair-use cap

### Why This Matters
- **Retention:** Morning ritual that pulls users into the app daily
- **Accessibility:** Hands-free briefing (commute, shower, cooking)
- **Privacy-first:** All numbers computed locally; model only does phrasing
- **Foundation:** Builds the LLM infrastructure for all downstream Personal AI slices (Ask LifeOS, Brain Dump, Weekly Brief, Money Insights, etc.)

### Technical
- **Depends on:** PBI-027a/027b (AI pipeline, already done)
- **Blocker:** PBI-027a/027b proxy must be deployed and tested live with a real provider first
- **LLM approach:** Cloud BYOK + managed (Recommended) — better Urdu support, production-ready
- **28 Acceptance Criteria** covering gate, consent, data privacy, LLM integration, voice, notifications, usage meter, fallback, testing, accessibility

### Cascades To
This is slice 039a of PBI-039 (Personal AI). All downstream slices (039b–g) reuse its:
- LLM gate & consent framework
- Request/response builder templates
- Usage meter infrastructure
- Managed cap enforcement

---

## 2. PBI-026 — Quick Capture Inbox: Dump & Sort Later

**File:** `PBI/PBI-026-quick-capture-inbox.md`

### What It Does
A single-tap inbox where you dump text, voice, photos, or files without deciding what they are yet. Later, you sort them into tasks, expenses, documents, or notes.

```
Workflow:
  ⊕ (FAB) → "Electricity bill due" → Inbox
  Later → Tap → "This is an Expense" → Parse amount → Saved
```

### Key Features
- ✅ **3 capture methods:**
  - 📝 Text quick-add (one-line, < 2 sec)
  - 🎤 Voice (reuses PBI-010 speech-to-text, Urdu + English)
  - 📸 Photo/file (camera or file picker)
- ✅ **Inbox list** with count badge, newest first
- ✅ **Quick classify modal** — Task / Expense / Document / Note (4 buttons)
- ✅ **Smart handoffs:**
  - Task → uses PBI-010 NL parser (live preview, can edit)
  - Expense → pre-fills amount if text contains a number
  - Document → uses PBI-003 confirm step (folder, person, tags)
  - Note → stays in inbox as archival (future Notes app)
- ✅ **Batch actions** — bulk-classify or bulk-delete
- ✅ **Undo** for 3 seconds after mark-done or delete
- ✅ **Soft delete** audit trail (no data loss)
- ✅ **Offline-first** — all captures stored locally in `captures` table
- ✅ **Optional notifications** (default on, togglable in Notification Diet)
- ✅ **Accessibility** — screen reader, Urdu support, no-hands voice

### Why This Matters
- **Daily anchor:** Low-friction entry point keeps users opening the app
- **Behavioral shift:** "Capture now, decide later" reduces friction vs. forcing a choice at capture time
- **Pairs with AI:** PBI-039c (Brain Dump to Plan) can read the inbox and propose multi-step plans ("This looks like a project — break it into tasks?")
- **Cross-domain:** Unifies task-add, expense-log, document-scan into one button

### Technical
- **Depends on:** PBI-002 (database), PBI-003, PBI-010, PBI-018 (reuses their forms)
- **Not blocking:** Any of those; adds a new capture path
- **New table:** `captures` with soft-delete, undo, batch ops
- **Schema:** v7 (incremented)
- **25 Acceptance Criteria** covering capture methods, inbox UI, classification, handoffs, state, UX, accessibility, offline, edge cases, testing

### Rollout Notes
- **MVP+1:** Fits at the end of MVP as S7 (post-device-QA from core 25 PBIs)
- **Free tier:** No caps (unlimited captures)
- **Pairs with:** PBI-010, PBI-003, PBI-018 (reuses existing flows)
- **Future:** Brain Dump to Plan (039c) will read and categorize

---

## Backlog Impact

| Item | Before | After | Change |
|---|---|---|---|
| **MVP PBIs** | 25 | 26 | +1 (PBI-026) |
| **MVP SP** | 158 | 166 | +8 |
| **Sprints** | 6 | 7 | +1 (S7: 026) |
| **Post-MVP** | 39 (PBI-039 only) | 39a + 039b–g + others | PBI-039 sliced; 039a drafted |

### Updated README

**File:** `PBI/README.md`

Changes:
- PBI-026 added to MVP row 26, Status "Ready"
- MVP total: 158 → 166 SP
- Sprint plan: S1–S6 (core MVP) + S7 (026, 8 SP)
- Sprint status: "MVP+1 additions" note added

---

## What's Next?

### For PBI-039a (Voice Brief)
1. **Tech spike:** Deploy PBI-027a/027b proxy to a live provider, confirm round-trip on a phone
2. **Groom LLM approach:** Decide between BYOK (recommended) or local-first fallback
3. **Draft prompts:** `daily_brief_v1.txt` (system + user template)
4. **Start dev** after spike (depends on 027a/027b live)

### For PBI-026 (Quick Capture)
1. **Schema migration:** Add `captures` table (schema v7)
2. **Start dev:** Can begin now (does not block any current work)
3. **Build order:**
   - Captures table + repo
   - Text/voice/photo forms
   - Inbox list
   - Classify modal + handoffs
   - Badge & notifications
   - Batch actions
   - Tests

---

## Design Alignment

Both features align with your **daily retention loop** and **privacy-first ethos**:

- **Voice Brief** = morning trigger (ritual at 07:30, or on-demand)
- **Quick Capture** = frictionless input during the day
- **Together** = "open, do something quick, close" habit loop

Both are **offline-first**, require **no cloud storage**, and **respect consent** (per-feature toggles).

---

## Files Created / Modified

| File | Action | Purpose |
|---|---|---|
| `PBI/PBI-039a-daily-voice-brief.md` | Created | Formal PBI for voice agent briefing |
| `PBI/PBI-026-quick-capture-inbox.md` | Created | Formal PBI for quick capture inbox |
| `PBI/README.md` | Updated | Added PBI-026 to MVP, updated totals, sprint plan |
| `FEATURE_UPDATES_2026-11-13.md` | Created | This summary |

---

## Questions to Clarify

### For Voice Brief (PBI-039a)
1. **LLM provider:** Confirmed BYOK + managed approach? Or local-first preferred for MVP?
2. **Proxy deployment:** Who owns deploying the 027b proxy? Timeline?
3. **Tone personalization:** Should brief tone match Life Score band (triage/steady/excellent) or be always neutral?

### For Quick Capture (PBI-026)
1. **Inbox location:** New tab in shell (Home / Tasks / **Inbox** / Vault / Money / More), or separate screen/bottom sheet?
2. **Note destination:** Keep notes in captures table, or a separate Notes feature?
3. **Batch UI:** Show as list with checkboxes, or pull-to-select?

---

**Created:** 2026-11-13  
**Status:** Both PBIs Ready to groom and schedule.
