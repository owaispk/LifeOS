# LifeOS — Complete Pending PBIs List (2026-11-13)

## Summary by Status

| Status | Count | Total SP | Notes |
|---|---|---|---|
| **Done** | 14 | 74 | Shipped, some device QA pending |
| **Ready** | 6 | 50 | Groomed, no blockers, can start immediately |
| **Ready (blocked)** | 4 | 34 | Groomed but waiting on dependency |
| **In Progress** | 2 | 18 | Dev or config work started, not complete |
| **Total Pending** | 26 | 176 | Not yet development-complete |

---

## 🟢 DONE (14 PBIs, 74 SP)

These are complete or nearly complete (some awaiting device QA):

| # | PBI | Epic | SP | Status | Notes |
|---|---|---|---|---|---|
| 27a | PBI-027a Premium AI: BYOK | E3 ATC / E1 Vault | 5 | Done | Client-side complete; user brings own key |
| 28a | PBI-028a Share Watermark & Document Bundles | E1 Vault | 5 | Done | Device QA passed 2026-11-11 ✅ |
| 29 | PBI-029 Premium Subscription & Free-Tier Limits | E5 Platform | 8 | Done (store setup pending) | Store setup still needed |
| 30 | PBI-030 Diagnostics Log & Share | E5 Platform | 3 | Done | ✅ Complete |
| 31 | PBI-031 Flagship: Compact, Professional Layout | E5 Platform / Design | 5 | Done | ✅ Complete |
| 32 | PBI-032 Device Calendar in Today View | E2 Mind | 5 | Done | Read-only calendar integration ✅ |
| 34 | PBI-034 Share Text to Task | E3 ATC / E2 Mind | 3 | Done (Android) | Android done; iOS needs Mac |
| 35 | PBI-035 Profile & Personalization | E5 Platform / E6 Engagement | 5 | Done | Neutral defaults enforced ✅ |
| 27b | PBI-027b Premium AI: Managed Mode + Proxy | E3 ATC / E1 Vault | 5 | Done (client); proxy undeployed | Client done; proxy not deployed yet |

**+ 5 MVP Core PBIs (001–025):** All done ✅

---

## 🟡 READY (6 PBIs, 50 SP)

Ready to groom and start immediately (no blockers):

| # | PBI | Epic | SP | Status | Blocker |
|---|---|---|---|---|---|
| 026 | PBI-026 Quick Capture Inbox | E2 Mind / E4 Money / E1 Vault | 8 | Ready | None ✅ |
| 026a | PBI-026a Account & Recovery Phrase | E5 Platform / Cloud | 8 | Ready | None ✅ |
| 037 | PBI-037 iOS Home-Screen Widget | E6 Engagement | 8 | Ready | Needs a Mac (not LifeOS blocker) |
| 039 | PBI-039 Personal AI: Ask, Plan, Insights | E7 Personal AI | 39 | Ready | None (start with 039a) |

---

## 🟠 READY (BLOCKED) (4 PBIs, 34 SP)

Groomed and ready, but waiting on dependencies:

| # | PBI | Epic | SP | Blocked By | Blocker Status |
|---|---|---|---|---|---|
| 026b | PBI-026b E2E Encrypted Backup & Restore | E5 Platform / Cloud | 13 | PBI-026a | Waiting for 026a |
| 026c | PBI-026c Multi-Device Sync | E5 Platform / Cloud | 13 | PBI-026b | Waiting for 026b (→ 026a) |
| 28b | PBI-028b Share-Safe Expiring Links | E1 Vault / Cloud | 8 | PBI-026b | Waiting for 026b (→ 026a) |

**Chain:** 026a → 026b → 026c & 028b

---

## 🔵 IN PROGRESS (2 PBIs, 18 SP)

Development started, device QA pending:

| # | PBI | Epic | SP | Progress | What's Left |
|---|---|---|---|---|---|
| 033 | PBI-033 Home-Screen Widget | E6 Engagement | 8 | Dev complete (Android) | Device QA; iOS split to follow-up |
| 036 | PBI-036 iOS Share Extension | E5 Platform | 5 | Config files written | Xcode target + device QA (needs Mac) |
| 038 | PBI-038 Testing Feedback | Cross-cutting | 13 | F-01–F-06 dev complete | Device QA + log remaining feedback |

**Note:** 036 & 037 blocked by "needs a Mac" (tooling, not technical LifeOS blocker)

---

## 🔴 NOT YET GROOMED (Spec V2/V3)

These are in the "Maybe" phase — not yet detailed PBIs:

| Feature Set | Description | Planned Phase |
|---|---|---|
| **V2 (P1)** | Health domain, People domain, Work/Study domain, Soul domain, Goals, full Money, Emergency Card, appointment OCR | Post-MVP, after 026 + 039a |
| **V3 (P2)** | Family sharing, HealthKit/steps, multi-currency, Arabic language | Future (likely 2027) |

---

## 📊 Complete Pending Backlog (by Status)

### All Post-MVP PBIs (26 items, 176 SP)

```
READY (0 blockers)
  ├─ 026  — Quick Capture Inbox (8 SP)           S7 ✅
  ├─ 026a — Account & Recovery (8 SP)           Ready
  ├─ 037  — iOS Widget (8 SP)                     Blocked: needs Mac (tooling)
  └─ 039  — Personal AI 39 SP (slices a–g)       Ready (start 039a)

READY BLOCKED (1 chain)
  ├─ 026b — E2E Backup (13 SP)                   ← waits for 026a
  ├─ 026c — Multi-Device Sync (13 SP)            ← waits for 026b
  └─ 028b — Expiring Links (8 SP)                ← waits for 026b

IN PROGRESS
  ├─ 033  — Home Widget (8 SP, Android done)     Device QA
  ├─ 036  — iOS Share Extension (5 SP)           Config done, Xcode + QA (needs Mac)
  └─ 038  — Testing Feedback (13 SP)             Dev done, device QA

DONE
  ├─ 027a — AI BYOK (5 SP) ✅
  ├─ 027b — AI Managed (5 SP) ✅ (proxy undeployed)
  ├─ 028a — Share & Bundles (5 SP) ✅
  ├─ 029  — Premium Tiers (8 SP) ✅ (store pending)
  ├─ 030  — Diagnostics (3 SP) ✅
  ├─ 031  — Flagship Layout (5 SP) ✅
  ├─ 032  — Device Calendar (5 SP) ✅
  ├─ 034  — Share to Task (3 SP) ✅ (Android)
  └─ 035  — Profile & Personalization (5 SP) ✅
```

---

## 🎯 All PBIs by Epic

### E1 Vault (Document Management)
| PBI | Title | SP | Status |
|---|---|---|---|
| 003 | Document Capture | 8 | Done ✅ |
| 004 | OCR, Classification & Extraction | 13 | Done ✅ |
| 005 | Vault Folders, People, Tags | 5 | Done ✅ |
| 006 | Vault Full-Text Search | 5 | Done ✅ |
| 007 | Document Viewer & Trash | 5 | Done ✅ |
| 008 | Expiry Guard | 5 | Done ✅ |
| 027a | Premium AI: BYOK | 5 | Done ✅ |
| 027b | Premium AI: Managed | 5 | Done ✅ (proxy undeployed) |
| 028a | Share Watermark & Bundles | 5 | Done ✅ |
| 028b | Share-Safe Expiring Links | 8 | Ready (blocked by 026b) |

### E2 Mind (Tasks)
| PBI | Title | SP | Status |
|---|---|---|---|
| 009 | Tasks: Today & Upcoming | 8 | Done ✅ |
| 010 | Natural-Language & Voice Add | 8 | Done ✅ |
| 011 | Overload Shield | 5 | Done ✅ |
| 026 | Quick Capture Inbox | 8 | Ready ✅ |
| 032 | Device Calendar in Today | 5 | Done ✅ |
| 034 | Share Text to Task | 3 | Done ✅ (Android) |

### E3 ATC (Automatic Task Creator / Payments)
| PBI | Title | SP | Status |
|---|---|---|---|
| 013 | ATC Monthly Payments | 8 | Done ✅ |
| 014 | ATC Bill Pattern Learning | 8 | Done ✅ |
| 015 | ATC Fees & Tuition | 5 | Done ✅ |
| 016 | Payment Completion Chain | 5 | Done ✅ |
| 017 | ATC Rules Manager | 3 | Done ✅ |
| 027a | Premium AI: BYOK | 5 | Done ✅ |
| 027b | Premium AI: Managed | 5 | Done ✅ |
| 034 | Share Text to Task | 3 | Done ✅ |

### E4 Money (Expenses & Forecasts)
| PBI | Title | SP | Status |
|---|---|---|---|
| 018 | Money Expense Log | 5 | Done ✅ |
| 019 | Monthly Forecast | 5 | Done ✅ |
| 026 | Quick Capture Inbox | 8 | Ready ✅ |

### E5 Platform (Infrastructure)
| PBI | Title | SP | Status |
|---|---|---|---|
| 001 | Project Foundation & Shell | 5 | Done ✅ |
| 002 | Offline-First Local Database | 8 | Done ✅ |
| 012 | Local Notifications | 8 | Done ✅ |
| 023 | Notification Diet | 5 | Done ✅ |
| 024 | App Lock & Encryption | 8 | Done ✅ |
| 025 | Settings, Export, EN/UR | 5 | Done ✅ |
| 026a | Account & Recovery Phrase | 8 | Ready ✅ |
| 026b | E2E Encrypted Backup & Restore | 13 | Ready (blocked by 026a) |
| 026c | Multi-Device Sync | 13 | Ready (blocked by 026b) |
| 029 | Premium Subscription & Free-Tier | 8 | Done ✅ (store pending) |
| 030 | Diagnostics Log & Share | 3 | Done ✅ |
| 031 | Flagship: Compact Layout | 5 | Done ✅ |
| 036 | iOS Share Extension | 5 | In progress (needs Mac) |

### E6 Engagement (User Retention)
| PBI | Title | SP | Status |
|---|---|---|---|
| 020 | Life Score v1 | 8 | Done ✅ |
| 021 | Home Dashboard | 5 | Done ✅ |
| 022 | Onboarding | 5 | Done ✅ |
| 033 | Home-Screen Widget | 8 | Dev complete (device QA pending) |
| 035 | Profile & Personalization | 5 | Done ✅ |
| 037 | iOS Home-Screen Widget | 8 | Ready (needs Mac) |

### E7 Personal AI (New)
| PBI | Title | SP | Status |
|---|---|---|---|
| 039 | Personal AI: Ask, Plan, Insights | 39 (7 slices) | Ready ✅ |
| 039a | Daily Voice Brief | 10 | Ready ✅ (slice of 039) |

### Cross-Cutting
| PBI | Title | SP | Status |
|---|---|---|---|
| 038 | Testing Feedback (Nov 2026) | 13 | Dev complete (device QA pending) |

---

## 🚀 Recommended Next Steps (Prioritized)

### IMMEDIATE (This Sprint)
1. **Finish device QA** for core MVP (PBI-001–025)
2. **Deploy 027b proxy** (tech spike) — blocker for 039a
3. **Start PBI-026** (Quick Capture) — no blockers, high value

### SPRINT S7
- Start **PBI-026** (Quick Capture Inbox, 8 SP)
- Design **PBI-039a** (Voice Brief) in parallel
- Plan **PBI-026a** (Account & Recovery)

### SPRINT S8
- Start **PBI-039a** (Voice Brief, 10 SP) — *after* 027b proxy deployment
- Device QA **PBI-033** (Home Widget)
- Start **PBI-026a** (Account & Recovery, 8 SP)

### SPRINT S9+
- **PBI-039b–g** (AI slices, 31 SP) — parallel track
- **PBI-026b–c** (backup/sync, 26 SP) — after 026a
- **PBI-028b** (Expiring Links, 8 SP) — after 026b

---

## 📊 Effort & Timeline

### Total Pending Work
- **26 PBIs**
- **176 Story Points**
- **2-dev capacity:** ~6–7 sprints (11–13 weeks)
- **1-dev capacity:** ~12–14 sprints (24–28 weeks)

### By Phase
| Phase | PBIs | SP | Sprints | Timeline |
|---|---|---|---|---|
| **MVP (Done)** | 25 | 158 | 6 | 12 weeks ✅ |
| **S7 (Next)** | 2 | 16 | 1 | 2 weeks |
| **S8–S9** | 6 | 60 | 2–3 | 4–6 weeks |
| **S10+** | 6+ | 100+ | 4+ | 8+ weeks |

---

## ✅ Dependency Chains

### 026a → 026b → 026c Chain (Backup/Sync)
```
PBI-026a (Account, 8 SP) ✅
  └─ PBI-026b (E2E Backup, 13 SP)
       └─ PBI-026c (Sync, 13 SP)
       └─ PBI-028b (Expiring Links, 8 SP)
Total: 42 SP, 3 sprints
```

### 027a → 027b → 039a Chain (AI)
```
PBI-027a (BYOK, 5 SP) ✅
  └─ PBI-027b (Managed, 5 SP) ✅ (proxy undeployed)
       └─ PBI-039a (Voice Brief, 10 SP) ⏳
            └─ PBI-039b–g (AI Slices, 31 SP)
Blocker: 027b proxy deployment
```

---

## 🎯 Status Summary by Count

```
READY (No blockers)        6 PBIs × 50 SP    → Start immediately
READY (Blocked)            4 PBIs × 34 SP    → After dependency
IN PROGRESS                3 PBIs × 26 SP    → Device QA / finish
DONE                      14 PBIs × 74 SP    → Shipped
────────────────────────────────────────────
TOTAL PENDING             26 PBIs × 176 SP   → 6–7 sprints
```

---

## 📝 How to Use This List

**For Planning:**
- Sprints S7–S12: Use the "Recommended Next Steps" section
- Dependency checks: Review the "Dependency Chains" section
- Epic grouping: See "All PBIs by Epic"

**For Development:**
- Ready items: See "READY (6 PBIs)" — start here
- Blocked items: See "READY (BLOCKED)" — use as reserve for parallel work
- In progress: See "IN PROGRESS" — finish first

**For Status:**
- Find any PBI in the tables above (searchable by #, title, SP, status)

---

**Created:** 2026-11-13  
**Status:** Complete reference  
**Next update:** After sprint review (weekly)
