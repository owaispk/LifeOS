# LifeOS Daily Retention Strategy (2026-11-13)

## The Problem
Users have great features (Vault, Tasks, Money, ATC), but **no morning ritual** to open the app daily.

## The Solution: Daily Loop

### Morning (Ritual at 07:30)
```
📲 Wake up
  ↓
🔔 Notification: "Your life update is ready"
  ↓
📢 Open LifeOS → Voice Brief (PBI-039a)
  ↓
Hear: "Good morning. 4 tasks, 1 bill due, 2 docs expiring, Life Score 78 — doing well."
  ↓
❓ Ask LifeOS (PBI-039b): "When's my passport due?" → "30 days. Renew soon."
```

**Result:** User starts the day informed, ready. Stays in app for 30–60 seconds.

---

### Throughout the Day (Instant Capture)
```
💡 Remember something during work/commute/home:
  → "Electricity bill to pay"
  → "Receipt for work expense"
  → "CNIC renewal reminder"
  
⊕ Tap Quick Capture FAB
  ↓
📝 Text: "Electricity bill due Friday" | 🎤 Voice | 📸 Photo
  ↓
Done → Saved to Inbox (no decisions needed yet)
```

**Result:** User can dump anything in < 3 seconds. No friction = more captures = app stays relevant.

---

### Evening / Later (Sort When Ready)
```
📥 Inbox shows: 3 captures waiting

For "Electricity bill due Friday":
  → Tap → "This is an Expense"
  → Amount pre-filled, category, date
  → Save → Done

For work receipt photo:
  → "This is a Document"
  → Opens confirm step (folder, person, tags)
  → Saved to Vault

For CNIC note:
  → "This is a Task"
  → Parsed: "Renew CNIC" due in 30 days
  → Saved to Today
```

**Result:** Weekly cleanup (once or twice), all domains stay up-to-date. No scrambling at month-end.

---

## How These PBIs Work Together

### Daily Retention Loop

| Time | Feature | Action | File | SP |
|---|---|---|---|---|
| **07:30 AM** | Voice Brief (039a) | Scheduled notification + speak update | PBI-039a | 10 |
| **During day** | Quick Capture (026) | Dump text/voice/photo to inbox | PBI-026 | 8 |
| **Optional** | Ask LifeOS (039b) | Question about own data | PBI-039b | 8 |
| **Evening** | Sort Inbox (026) | Move captures to tasks/expenses/documents | PBI-026 | (same) |

### Brain Dump Pairing (Future, PBI-039c)
```
🧠 Brain dump (unstructured voice/text):
  "Next week I need to plan the family trip, 
   budget is 50k, I need to book tickets 
   and hotel by Thursday"

↓ AI parses:
  Task: "Book flight tickets" (Thu)
  Task: "Book hotel" (Thu)
  Task: "Plan family trip" (next week)
  Expense: "Travel budget: 50k"

↓ User reviews & saves
```

---

## Why This Drives Daily Retention

| Metric | Impact | Mechanism |
|---|---|---|
| **Morning opens** | ⬆️ +50–70% | Scheduled notification + voice ritual (async engagement) |
| **Session length** | ⬆️ 30–60 sec | Brief takes 30s, Q&A another 15–30s |
| **Frequency** | ⬆️ +daily | Quick Capture removes friction (captures during day) |
| **User confidence** | ⬆️ Higher | Daily brief + ask = feeling of control; inbox offloads decision |
| **Habit formation** | ⬆️ Strong | Ritual (morning) + reward (information) + low friction = habit loop |

### Comparison: Before vs. After

**Before (MVP 25 PBIs):**
- User open app when they remember → no daily trigger
- Adding anything requires choosing destination (task/expense/document)
- Monthly churn: "I didn't remember to log everything"

**After (MVP + 026 + 039a):**
- 07:30 notification pulls user in → morning ritual
- 10+ captures throughout week → low friction
- Evening sort → batch processing (one 5-min session vs. 10 context switches)
- Result: **Daily active, engaged, in control**

---

## Why Voice Brief is the MVP Hero

Unlike text notifications:
- ✅ **Hands-free:** Works during commute, exercise, cooking
- ✅ **Rich:** 30 seconds of audio = more context than "3 tasks · 1 bill due"
- ✅ **Engaging:** Feels like a personal assistant, not a ping
- ✅ **Accessible:** Urdu voice = differentiator in Pakistan/diaspora market
- ✅ **Premium upsell:** Cloud LLM is premium feature (managed mode)

---

## Why Quick Capture is MVP Critical

Without it:
- Users still bounce on task-add ("Add what? Expense or task or document?")
- Photos still land in Photos folder, not captured in LifeOS
- Voice notes still go to Notes, not searchable in Vault

With Quick Capture:
- One button for everything
- No friction = habit forming
- Inbox batches decisions (sort once per day)
- Pairs perfectly with Brain Dump AI (039c)

---

## Backlog Sequencing

### Phase 1: Core MVP (S1–S6, 25 PBIs, 158 SP)
```
✅ Foundation: Vault, Tasks, Money, ATC, Notifications, Settings, Security
```

### Phase 2: Daily Retention (S7 onward)
```
S7 → PBI-026 (Quick Capture Inbox, 8 SP)
     └─ Builds capture flows, soft-delete, inbox UX

Post-S7 → PBI-039a (Voice Brief, 10 SP)
          └─ Builds LLM layer, TTS, scheduled notifications
          └─ Platform for 039b–g

Parallel → PBI-039b (Ask LifeOS, 8 SP)
           PBI-039c (Brain Dump to Plan, 5 SP)
           PBI-039d (Weekly Brief, 5 SP)
           PBI-039e (Money Insights, 5 SP)
           PBI-039f (Renewal Checklist, 5 SP)
           PBI-039g (Document Actions, 3 SP)
```

---

## User Personas & Impact

### Parent (School pickups, bills, docs)
- **Morning:** "School forms due Friday, medical insurance expires next month"
- **Capture:** Photo of school form, voice "buy school supplies"
- **Benefit:** Never miss a deadline; voice AI helps with multi-step tasks

### Freelancer (Projects, invoices, receipts)
- **Morning:** "3 invoices overdue, 4 projects in flight, spending 30% over budget"
- **Capture:** Receipt photos, project voice notes
- **Benefit:** Weekly brief pinpoints money leaks; inbox batches (no app fatigue)

### Student (Tuition, deadlines, documents)
- **Morning:** "Tuition payment due in 5 days; 2 assignments due this week"
- **Capture:** Fee voucher photo, assignment notes
- **Benefit:** Overload Shield prevents burnout; voice feels like a mentor

---

## Success Metrics (Post-Launch)

| KPI | Target | How Measured |
|---|---|---|
| **DAU (Daily Active Users)** | 50–70% of install base | App open events + session start log |
| **Morning ritual adoption** | 40–50% | Voice Brief notifications sent / enabled |
| **Avg. captures/user/week** | 5–10 | `captures` table, pending → done transitions |
| **Inbox sort time** | < 5 min/week | Session duration, inbox flows |
| **Session frequency** | 5–7 per week | App open events |
| **Retention (30-day)** | 60–70% | Cohort retention analysis |

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Voice Brief TTS too slow (> 3 sec) | Pre-compute brief in background; cache replies; test on devices |
| LLM provider unreachable | Plain-text fallback always available (no errors) |
| Captures table fills disk (1000s) | Soft-delete + archive old captures; optional export |
| Quick Capture "spray and pray" (junk) | Undo + reminder on overdue captures; note → auto-delete after 30d |
| Inbox too many choices (task/expense/doc/note) | Start with smart default (AI pre-classifies if 039c available); user can override |

---

## Timeline (Estimated)

| Phase | PBIs | SP | Duration | Notes |
|---|---|---|---|---|
| **Core MVP** | 001–025 | 158 | ~12 weeks (6 sprints × 2 dev, done) | ✅ Device QA complete |
| **S7: Quick Capture** | 026 | 8 | ~1–2 weeks | Can start immediately |
| **S8: Voice Brief** | 039a | 10 | ~2 weeks | Blocked on 027b proxy deployment |
| **S9–S12: AI Slices** | 039b–g | 31 | ~4–6 weeks | Build in parallel; demo 039b (Ask LifeOS) |

**Total:** ~20–26 weeks from now to full daily-retention stack (MVP + 026 + 039a–g).

---

## Next Steps

### Immediate (This Week)
1. ✅ Draft PBI-039a (Voice Brief) — **Done**
2. ✅ Draft PBI-026 (Quick Capture) — **Done**
3. Review both PBIs with team (dev, design, product)
4. Clarify questions (LLM provider, proxy deployment timeline, Inbox location)

### Next Sprint (S7)
1. Schedule PBI-026 (Quick Capture) for development
2. Tech spike: confirm 027a/027b proxy deployment + round-trip test
3. Draft LLM prompts for 039a (Voice Brief)

### S8+
1. Start PBI-039a (Voice Brief) after proxy is live
2. Parallel: PBI-039b (Ask LifeOS) design + schema
3. Kick off AI slice development (039b–g)

---

## Conclusion

**Quick Capture (026)** + **Voice Brief (039a)** = **daily retention hook**

- Morning notification + voice assistant = "why I open the app"
- Frictionless capture = "why I stay in the app"
- Batch inbox sort = "how I feel in control"

Together, they transform LifeOS from a "tool I use when I remember" to a **daily habit**.

---

**Document:** DAILY_RETENTION_STRATEGY.md  
**Date:** 2026-11-13  
**Status:** Strategy complete; PBIs ready to groom and schedule.
