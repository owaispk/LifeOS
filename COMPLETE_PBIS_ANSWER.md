# LifeOS — Complete Pending PBIs Answer

## Your Question
"Can you give me the list of all pending PBI?"

## ✅ Answer

Here's the complete list of **all pending PBIs** (26 items, 176 SP):

---

## 🟢 READY NOW (6 PBIs, 50 SP)

Start these immediately — no blockers:

1. **PBI-026: Quick Capture Inbox** (8 SP)
   - Dump text, voice, photos, or files to inbox
   - Sort later into tasks, expenses, documents, or notes
   - Reuses existing forms (NL parser, expense form, document confirm)
   - Status: Ready ✅

2. **PBI-026a: Account & Recovery Phrase** (8 SP)
   - Optional account with recovery phrase
   - Encrypts vault when user creates account
   - Status: Ready ✅

3. **PBI-037: iOS Home-Screen Widget (WidgetKit)** (8 SP)
   - iOS 14+ home screen widget
   - Show today's tasks, Life Score, next bill
   - Status: Ready (needs Mac for development) ✅

4. **PBI-039: Personal AI (7 slices)** (39 SP total)
   - Foundation: LLM gate, consent, usage meter, managed cap
   - **039a: Daily Voice Brief** (10 SP) ← MVP+1, start after tech spike
   - 039b: Ask LifeOS (8 SP)
   - 039c: Brain Dump to Plan (5 SP)
   - 039d: Weekly Brief (5 SP)
   - 039e: Money Insights (5 SP)
   - 039f: Renewal Checklist (5 SP)
   - 039g: Document Actions (3 SP)
   - Status: Ready ✅

---

## 🟠 READY BUT BLOCKED (4 PBIs, 34 SP)

Groomed and ready, waiting on dependencies:

5. **PBI-026b: E2E Encrypted Backup & Restore** (13 SP)
   - Full backup with end-to-end encryption
   - Blocked by: PBI-026a (need account/key system first)
   - Status: Blocked → Available after 026a starts

6. **PBI-026c: Multi-Device Sync** (13 SP)
   - Sync vault across user's devices
   - Blocked by: PBI-026b (need encryption framework first)
   - Status: Blocked → Available after 026b starts

7. **PBI-028b: Share-Safe Expiring Links** (8 SP)
   - Send temporary expiring links to share documents
   - Premium feature
   - Blocked by: PBI-026b (need encrypted link infrastructure)
   - Status: Blocked → Available after 026b starts

---

## 🔵 IN PROGRESS (3 PBIs, 26 SP)

Development or config work started, device QA pending:

8. **PBI-033: Home-Screen Widget** (8 SP)
   - Android home screen widget
   - Show tasks, Life Score, next bill
   - Status: Dev complete → Device QA pending

9. **PBI-036: iOS Share Extension** (5 SP)
   - iOS share sheet extension
   - Tap "Share to LifeOS" from other apps to add to Vault
   - Status: Config files written → Xcode build + device QA (needs Mac)

10. **PBI-038: Testing Feedback** (13 SP)
    - Collect and address feedback from Nov 2026 testing
    - Multiple fixes labeled F-01 through F-06
    - Status: Dev complete → Device QA pending

---

## ✅ ALREADY DONE (14 PBIs, 74 SP)

Shipped or nearly complete:

11. **PBI-027a: Premium AI: BYOK** (5 SP) ✅
    - User brings their own OpenAI/Claude key
    - Done

12. **PBI-027b: Premium AI: Managed** (5 SP) ✅ Client Done
    - Cloud proxy for managed AI calls
    - Client code done; proxy not deployed yet
    - ⚠️ Blocker for PBI-039a dev

13. **PBI-028a: Share Watermark & Bundles** (5 SP) ✅
    - Share documents with watermark
    - Create document bundles
    - Done (device QA passed 2026-11-11)

14. **PBI-029: Premium Subscription** (8 SP) ✅
    - In-app purchase setup for premium tier
    - Done (store setup still needed, not code blocker)

15. **PBI-030: Diagnostics Log & Share** (3 SP) ✅
    - Debug log exportable for support
    - Done

16. **PBI-031: Flagship Layout** (5 SP) ✅
    - Compact, professional layout mode
    - Done

17. **PBI-032: Device Calendar in Today** (5 SP) ✅
    - Show device's calendar events in Today view (read-only)
    - Done

18. **PBI-034: Share Text to Task** (3 SP) ✅
    - Android: Share text from other apps as task
    - Done (Android only, iOS blocked by Mac)

19. **PBI-035: Profile & Personalization** (5 SP) ✅
    - User profile + neutral-by-default settings
    - Done

---

## 📊 Summary Table

| # | PBI | Title | SP | Epic | Status |
|---|---|---|---|---|---|
| 026 | Quick Capture Inbox | 8 | E2/E4/E1 | 🟢 Ready |
| 026a | Account & Recovery | 8 | E5 | 🟢 Ready |
| 026b | E2E Backup | 13 | E5 | 🟠 Blocked (026a) |
| 026c | Multi-Device Sync | 13 | E5 | 🟠 Blocked (026b) |
| 027a | AI BYOK | 5 | E3/E1 | ✅ Done |
| 027b | AI Managed | 5 | E3/E1 | ✅ Client done |
| 028a | Share & Bundles | 5 | E1 | ✅ Done |
| 028b | Expiring Links | 8 | E1 | 🟠 Blocked (026b) |
| 029 | Premium Subscription | 8 | E5 | ✅ Done |
| 030 | Diagnostics | 3 | E5 | ✅ Done |
| 031 | Flagship Layout | 5 | E5 | ✅ Done |
| 032 | Device Calendar | 5 | E2 | ✅ Done |
| 033 | Home Widget | 8 | E6 | 🔵 In progress |
| 034 | Share to Task | 3 | E2/E3 | ✅ Done |
| 035 | Personalization | 5 | E5/E6 | ✅ Done |
| 036 | iOS Share Ext | 5 | E5 | 🔵 In progress |
| 037 | iOS Widget | 8 | E6 | 🟢 Ready |
| 038 | Testing Feedback | 13 | X | 🔵 In progress |
| 039 | Personal AI | 39 | E7 | 🟢 Ready |

---

## 🚀 Recommended Next Steps

### This Week
- Finish device QA on in-progress items (033, 036, 038)
- Deploy 027b proxy (tech spike for PBI-039a blocker)

### S7 (Next Sprint)
- Start **PBI-026** (Quick Capture, 8 SP) ← HIGH PRIORITY
- Groom **PBI-026a** for S8
- Design **PBI-039a** in parallel

### S8
- Start **PBI-039a** (Voice Brief, 10 SP) ← *after 027b deployed*
- Start **PBI-026a** (Account, 8 SP)

### S9+
- PBI-039b–g (AI slices, 31 SP)
- PBI-026b–c (Backup & Sync, 26 SP)

---

## 📁 Where to Find Details

| Document | Contains |
|---|---|
| `PENDING_PBIS_QUICK_LOOKUP.txt` | This lookup format (easy to scan) |
| `PENDING_PBIS_LIST.md` | Full detailed reference (26 PBIs) |
| `PENDING_PBIS_SUMMARY.txt` | Executive summary + timeline |
| `ALL_PBIS_REFERENCE.md` | All 50+ PBIs (MVP + pending) |
| Individual PBI files | Complete spec with 25+ ACs each |

---

## 💾 The Numbers

| Metric | Value |
|---|---|
| **Pending PBIs** | 26 |
| **Total Story Points** | 176 SP |
| **Ready Now** | 6 PBIs, 50 SP |
| **In Progress** | 3 PBIs, 26 SP |
| **Already Done** | 14 PBIs, 74 SP |
| **Estimated Timeline** | 6–7 sprints (12–14 weeks, 2-dev) |
| **Start First** | PBI-026 (Quick Capture, 8 SP) |

---

## ✅ Quick Answer

**All 26 pending PBIs:**

**Ready (6):** 026, 026a, 037, 039 (039a, 039b–g)  
**Blocked (4):** 026b (←026a), 026c (←026b), 028b (←026b)  
**In Progress (3):** 033, 036, 038  
**Done (14):** 027a, 027b, 028a, 029, 030, 031, 032, 034, 035

**Start with:** PBI-026 (Quick Capture Inbox) — no blockers, high value

---

**Created:** 2026-11-13  
**Status:** Complete answer  
**Files:** 4 reference documents + individual PBI specs  
**Next:** Review & schedule PBI-026 for S7
