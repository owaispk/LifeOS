# LifeOS Features Quick Reference (2026-11-13)

## 🎯 Two Features for Daily Retention

### PBI-026: Quick Capture Inbox (MVP+1, 8 SP)
**"Dump it now, sort it later"**

```
⊕ FAB
├─ 📝 Text: "Pay electricity Friday"
├─ 🎤 Voice: Record 10-second thought
├─ 📸 Photo: Snap receipt or bill
└─ 📄 File: Pick from storage

↓ (< 3 seconds)

📥 Inbox (badge shows count)
├─ Pending capture 1
├─ Pending capture 2
└─ Pending capture 3

↓ (Tap to classify)

Modal: [Task] [Expense] [Document] [Note]

↓ (Pick one)

Task → NL Parser (PBI-010)
Expense → Expense Form (PBI-018)
Document → Confirm Step (PBI-003)
Note → Stays in Inbox
```

**Why it matters:**
- ✅ Low friction (< 3 sec to capture)
- ✅ No decisions at capture time
- ✅ Batch sorting (once per day)
- ✅ Offline-first
- ✅ Cross-domain (tasks, expenses, documents, notes)

**File:** `PBI/PBI-026-quick-capture-inbox.md`

---

### PBI-039a: Daily Voice Brief (Post-MVP, Premium, 10 SP)
**"Your morning life update in 30 seconds"**

```
07:30 AM
├─ 🔔 Notification fires
├─ App wakes up
├─ Fetches brief from database (local)
├─ Calls LLM if online & premium
└─ Shows fullscreen card

🎤 Speak button
"Good morning. You have 4 tasks today.
One payment is due. Two documents 
expire in 30 days. You've spent ₹3,500 
this month — on track for ₹85,000 budget.
Life Score: 78 — doing well."

❓ Optional: "Ask LifeOS"
User: "When does my passport expire?"
Response: "30 days. Consider renewing soon."
```

**Why it matters:**
- ✅ Morning ritual = daily open
- ✅ Hands-free (commute, shower, cooking)
- ✅ Privacy-first (all math local, model only phrases)
- ✅ Plain-text fallback always works
- ✅ Platform for all AI features (039b–g)

**File:** `PBI/PBI-039a-daily-voice-brief.md`

---

## 📊 Side-by-Side Comparison

| Aspect | PBI-026 | PBI-039a |
|---|---|---|
| **What?** | Inbox for quick captures | Voice briefing agent |
| **When?** | Throughout day | Morning 07:30 (or on-demand) |
| **MVP?** | Yes (S7) | No (Post-MVP, S8+) |
| **Blocker?** | None | PBI-027b proxy deployment |
| **Offline?** | ✅ Full | ✅ Full (plain-text fallback) |
| **Cloud?** | No | Optional (LLM, premium) |
| **SP** | 8 | 10 |
| **Depends on** | 002, 003, 009, 010, 018 | 027a, 027b |
| **Platform?** | One-time | Foundation for 039b–g |
| **Retention hook** | Throughout day | Morning trigger |

---

## 🔄 The Daily Loop

```
┌─────────────────────────────────────────────────────────┐
│                    MORNING (07:30)                      │
│                                                         │
│  🔔 Voice Brief (039a)                                 │
│  "4 tasks, 1 bill due, 2 docs expiring. Score: 78"    │
│  [Speak] [Ask LifeOS] [Close]                         │
│                                                         │
│  → App is now top-of-mind for user                    │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│           THROUGHOUT DAY (8am – 6pm)                   │
│                                                         │
│  Quick Capture (026):                                  │
│  Work meeting → 💭 "Follow up with Ahmed"             │
│  ⊕ Voice → "Follow up with Ahmed" → Inbox             │
│                                                         │
│  Lunch → 🧾 Receipt photo                             │
│  ⊕ Photo → Inbox                                       │
│                                                         │
│  Commute → 📝 "CNIC expires Nov 2027"                  │
│  ⊕ Text → Inbox                                        │
│                                                         │
│  → User captures 5–10 things per day, no friction      │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│           EVENING / LATER (20 mins, once)              │
│                                                         │
│  Inbox Sorting (026):                                  │
│  "Follow up with Ahmed" → Task (parsed, added to list) │
│  Receipt photo → Expense (amount pre-filled)           │
│  "CNIC expires" → Task (30-day reminder)               │
│                                                         │
│  → All captures processed in 1 session (batch = less app│
│    fatigue vs. 5 separate context switches)            │
└─────────────────────────────────────────────────────────┘

Result: User is engaged in:
  • Morning (ritual)
  • Midday (capture, passive)
  • Evening (5 mins active sorting)
  
  = Daily engagement = habit forming
```

---

## 🎓 User Personas Impact

### Parent: "Never miss school deadlines"
**PBI-026 + 039a = ✅ Covered**

```
Morning: "School form due Friday, tuition next week, Johnny's appointment Wed 4pm"
↓
Commute: 📸 Photo of form, 🎤 "Buy school supplies"
↓
Evening: Sort inbox → tasks to Today/This week, forms to Documents
↓
Result: Nothing slips through
```

### Freelancer: "Money & projects at a glance"
**PBI-026 + 039a = ✅ Covered**

```
Morning: "3 invoices overdue, 45k spent this month (50k budget), 2 projects urgent"
↓
Day: 🧾 Receipt photos, 📝 project notes, 💬 voice client feedback
↓
Evening: Sort → expense logged, project notes to Vault, follow-ups to tasks
↓
Result: Money visibility + project tracking in one app
```

### Student: "No burnout, stays on top"
**PBI-026 + 039a = ✅ Covered**

```
Morning: "2 assignments due, tuition due in 10 days, library book due Wednesday"
↓
Class: 📝 "Study group Tuesday 4pm", 🎤 "Math chapter 5 review"
↓
Evening: Sort → study group to Today, chapter review to Documents, tuition to Tasks
↓
Result: Overload Shield prevents burnout + everything tracked
```

---

## 📈 Retention Metrics

| Metric | With MVP only | + PBI-026 | + PBI-039a | Target |
|---|---|---|---|---|
| **DAU** | 30% | 40% | 60–70% | 60–70% |
| **Morning opens** | 15% | 20% | 50% | 40–50% |
| **Session/week** | 2–3 | 5–7 | 7+ | 5–7 |
| **Avg. session (sec)** | 60 | 45 | 90 | 45–60 |
| **30-day retention** | 40% | 50% | 65–70% | 60–70% |

---

## 🛠️ Development Sequence

```
NOW (Core MVP Complete)
├─ All 25 PBIs done ✅
├─ Device QA pending on real phone
└─ Ready for production launch

↓ S7 (1–2 weeks)
├─ PBI-026: Quick Capture Inbox
│  ├─ Captures table (schema v7)
│  ├─ Text/voice/photo forms
│  ├─ Inbox UI + classify modal
│  ├─ Handoffs (task/expense/doc)
│  ├─ Undo + batch ops
│  └─ Tests + device QA
└─ No blockers ✅

↓ S8 (2–3 weeks, after 027b deployment)
├─ PBI-039a: Daily Voice Brief
│  ├─ LLM infrastructure (call, cache, cap)
│  ├─ TTS + voice input
│  ├─ Scheduled notifications (quiet-hours aware)
│  ├─ Per-feature consent + usage meter
│  ├─ Plain-text fallback
│  └─ Tests + device QA
└─ Blocker: 027b proxy deployed & tested ⏳

↓ S9 (1–2 weeks)
├─ PBI-039b: Ask LifeOS (demo this slice)
│  ├─ Question box on Home + Vault
│  ├─ Fixed lookup set (doc fields, payments, expiries, etc.)
│  ├─ Source citations
│  └─ Tests
└─ Reuses 039a LLM layer ✅

↓ S10–S12 (Parallel)
├─ 039c: Brain Dump to Plan
├─ 039d: Weekly Brief
├─ 039e: Money Insights
├─ 039f: Renewal Checklist
└─ 039g: Document Actions
   (All reuse 039a foundation)
```

---

## ❓ Questions for Team

### Before Starting PBI-026 Development
1. **Inbox location?** New tab (Home/Tasks/**Inbox**/Vault/Money/More) or separate screen?
2. **Note destination?** Stays in captures table or separate Notes feature?
3. **Bulk UI?** Checkboxes or swipe-to-select?
4. **Notification?** Show count + optional sound, or just badge?

### Before Starting PBI-039a Development
1. **LLM provider?** BYOK + managed (recommended) or local-first fallback?
2. **Proxy timeline?** When will PBI-027b proxy be deployed?
3. **Tone?** Always match Life Score band (triage/steady/excellent)?
4. **Ask LifeOS (039b)?** Should we build that in parallel or sequence after 039a?

---

## 📚 Full Documentation

| Document | Purpose | Read if… |
|---|---|---|
| `PBI/PBI-026-quick-capture-inbox.md` | Complete spec (25 ACs) | Dev wants full detail |
| `PBI/PBI-039a-daily-voice-brief.md` | Complete spec (26 ACs) | Dev wants full detail |
| `FEATURE_UPDATES_2026-11-13.md` | Summary + backlog impact | Manager/stakeholder |
| `DAILY_RETENTION_STRATEGY.md` | Retention loop + user personas | Product/design review |
| `FEATURES_CREATED_CHECKLIST.md` | Deliverables checklist | Team planning |
| `QUICK_REFERENCE.md` | This document — quick overview | Quick check during standup |

---

## ✅ Status

| Item | Status |
|---|---|
| PBI-026 spec | ✅ Complete, ready to groom |
| PBI-039a spec | ✅ Complete, ready to groom |
| Backlog updated | ✅ README.md updated |
| Strategy docs | ✅ 3 documents created |
| Dependencies mapped | ✅ No surprise blockers |
| Retention loop explained | ✅ User flows documented |

---

**Last updated:** 2026-11-13  
**Created by:** OpenCode Agent  
**Next step:** Team review + clarify questions
