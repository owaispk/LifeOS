# LifeOS — Deep Feature Specification (Groomed)

**Version:** 1.0 · **Date:** 2026-11-08
**Tagline:** One app to run your entire life — plans, money, health, and every important paper you own.
**Target user:** Any person in any field (student, doctor, freelancer, parent, businessman) managing tasks, bills, health, documents, and family responsibilities.

---

## Legend
- **Priority:** P0 = MVP (launch), P1 = Version 2, P2 = Version 3+
- **US** = User Story · **AC** = Acceptance Criteria · **EC** = Edge Cases

---

# 1. 📂 Document Vault (P0 — Star Feature)

## 1.1 Document Capture
**US:** As a user, I want to scan any paper with my camera so it becomes a clean digital document.

**Features:**
- Camera scan with auto edge detection, auto-crop, perspective correction
- Enhance modes: original / grayscale / high-contrast document mode
- Multi-page scanning → single PDF
- Import from gallery, files, WhatsApp-shared PDFs/images
- Batch scan mode (scan 10 documents in one session, file them after)

**AC:**
- Scan → saved document in under 10 seconds
- Output formats: PDF (default), JPEG
- Works 100% offline

**EC:**
- Blurry capture → prompt "Retake? Image looks unclear"
- Low storage → warn before scan session
- Duplicate detection: same document scanned twice → "Looks like a duplicate of 'Electricity Bill Oct'. Keep both?"

## 1.2 AI Auto-Classification (OCR)
**US:** As a user, I want the app to recognize what I scanned so I don't have to name and file it manually.

**Features:**
- On-device OCR (ML Kit) extracts text from scan
- Classifier detects document type: CNIC, passport, bill, fee voucher, prescription, degree, warranty, receipt, agreement, other
- Auto-extracts key fields per type:
  - **Bill:** issuer, amount, due date, billing month, reference number
  - **ID/Passport:** name, number, expiry date
  - **Fee voucher:** institution, student name, amount, due date
  - **Prescription:** date, doctor name
  - **Warranty/Policy:** product, start date, end date
- Auto-title: "K-Electric Bill — Nov 2026"
- User confirms or edits in one tap before saving (never silently wrong)

**AC:**
- Classification confidence shown; below threshold → ask user to pick type
- All extracted fields editable
- Extraction works offline for Urdu-script numerals and English

**EC:**
- Unreadable document → save as "Unclassified", user tags manually
- Wrong extraction → user correction is remembered (per-issuer learning)

## 1.3 Organization & Search
**Features:**
- **Smart folders (auto):** Identity, Education, Medical, Property, Vehicles, Bills & Receipts, Work, Insurance
- **People profiles:** Me / Spouse / Child 1 / Parents — every document belongs to a person
- Custom folders and tags
- Full-text search (search inside documents via stored OCR text): type "passport" or "K-Electric 4500" → instant result
- Filters: person, type, date range, expiring soon
- Favorites / pinned documents

**AC:**
- Search results < 1 second, offline
- A document can belong to one person + multiple tags

## 1.4 Expiry Guard
**US:** As a user, I want to be warned before any document expires so I never face a last-minute crisis.

**Features:**
- Every document can hold an expiry/due date (auto-extracted or manual)
- Default alert ladder: 90 / 30 / 7 / 1 days before expiry (configurable per type)
  - Passport/visa: 6 months + 3 months + 1 month (travel rules)
  - Bills: 3 days + due date + overdue
- "Expiring Soon" dashboard section, sorted by urgency
- Expiry affects Life Score (see §9)
- Renewal flow: mark renewed → scan new document → old one auto-archived (kept, not deleted)

**EC:**
- Expired and ignored → weekly digest nudge, not daily spam
- No date found → gentle one-time prompt "Does this document expire?"

## 1.5 Sharing
**Features:**
- Share as PDF/image via any app
- **Share-safe links:** cloud link that auto-expires (1 hour / 24 hours / 7 days), optional PIN
- Watermark option: "Shared by [name] for [purpose] — [date]" overlaid on shared copy
- Share bundles: select Degree + CNIC + Photo → one PDF "Job Application Pack"
- Audit trail: when/what was shared, revoke active links

**EC:**
- Link opened after expiry → "This document is no longer available"
- Offline → queue link creation, share file directly instead

## 1.6 Security (Vault-specific)
- Biometric/PIN gate on Vault open (separate from app lock, optional)
- AES-256 encryption at rest, on device, before any upload
- End-to-end encrypted cloud backup (premium) — server cannot read documents
- Auto-lock after N minutes
- Screenshot blocking inside Vault (Android FLAG_SECURE), optional
- Decoy safety: no document contents in notifications ("A document expires soon", not "Your passport AB1234…")

## 1.7 Emergency Card (P1)
- One screen: blood group, allergies, conditions, emergency contacts, insurance policy number
- Accessible from lock-screen widget / app without full unlock (user opts in)
- Printable wallet-card PDF export

---

# 2. ⚡ Auto Task Creator — ATC (P0)

## 2.1 Principles
1. **Never silently create** — every new recurring pattern asks once: "Create this monthly task? ✓ / ✗". After approval, runs forever.
2. **Every auto-task shows its source** — "Created from: Electricity bill scanned 12 Oct".
3. **User can mute any source** per item ("stop predicting internet bill").

## 2.2 Trigger Source A — Appointments
**US:** As a user, when I add or scan an appointment, the app should handle all the reminders and preparation.

**Flow:**
1. Appointment enters via: manual add, scanned slip (OCR reads date/time/doctor), or calendar import (P1)
2. ATC creates: main task + reminders (1 day before, 2 hours before — configurable)
3. Context attach: if person has medical documents, sub-task "Bring previous reports" with links to the latest 3 reports
4. Post-appointment follow-up: at appointment time + 3h, ask "Was there a follow-up date?" → one tap creates the next cycle

**EC:**
- Appointment in the past → ask "Did this already happen? Log it instead?"
- Conflict: two appointments overlap → warn at creation

## 2.3 Trigger Source B — Bill Pattern Learning
**US:** As a user, I want the app to learn when my bills arrive and remind me before I even receive them.

**Logic:**
- Each paid/scanned bill records: issuer, billing month, arrival date, due date, amount
- After **2 consistent cycles**, ATC proposes: "Electricity bill usually arrives 10th–14th. Create a monthly reminder?"
- Predicted task: "Expect electricity bill (~Rs 4,000–6,000 based on history)" on predicted arrival date
- When the real bill is scanned → predicted task upgrades: exact amount + due date from OCR, reminder ladder set to due date
- Overdue protection: due date reached, unpaid → task turns red, moves to top, daily reminder until paid or dismissed

**Per-bill learning:** electricity, gas, water, internet, mobile, TV — each learns its own cycle and amount range.

**EC:**
- Bill skipped a month → "No gas bill this month — did you miss it, or should I pause this reminder?"
- Amount spike: new bill > 2× average → highlight "Unusually high bill ⚠" (loved feature, costs nothing)
- Two meters / two houses → issuer + reference number distinguishes them

## 2.4 Trigger Source C — Fees & Tuition
**Flow:**
- One-time setup OR first scanned voucher: institution, person (which child), amount, cycle (monthly / quarterly / semester), due day
- Auto-creates "Ali — school fee Rs 12,000, due 5th" every cycle, 5 days before due
- Scanned voucher updates amount automatically (fee increases detected: "Fee increased from 12,000 → 13,500. Update future tasks?")
- Receipt attached → task completes → receipt filed in Vault under the child's Education folder → expense logged in Money

**EC:**
- Vacation months (no fee) → per-item skip months setting
- Semester systems → date-based, not monthly

## 2.5 Trigger Source D — Monthly Payments Engine
**Setup screen:** "What do you pay regularly?" — guided checklist:

| Type | Fields | Behavior |
|---|---|---|
| Rent | amount, day | fixed task monthly |
| School fees | per child, amount, day | fee flow (§2.4) |
| Utility bills | issuer | learned pattern (§2.3) |
| Internet/mobile | amount, day | fixed |
| Installments/Committee (BC) | amount, day, total months | fixed + countdown "7 of 24 paid" |
| Subscriptions | amount, day | fixed, yearly-review nudge |
| Custom | name, amount, cycle | fixed |

**Monthly Money Forecast:**
- 1st of month (and on demand): "November fixed payments: Rs 61,500 across 6 items" with list and dates
- Salary-aware mode (optional): user sets salary date → payment tasks scheduled after it; forecast shows "Rs 61,500 of Rs 150,000 (41%) goes to fixed payments"

**Completion chain (the magic):** Mark paid → optionally attach receipt (scan or photo) → receipt filed in Vault → expense auto-logged in Money with category → Life Score updates. One action, four results.

## 2.6 ATC Management Screen
- List of all active auto-rules with source, next run, last run
- Pause / edit / delete any rule
- History log: "Tasks created by ATC this month: 14"

---

# 3. 🧠 Mind — Tasks & Goals (P0 tasks, P1 goals)

## 3.1 Tasks
- Quick add: text, voice (Urdu/English — on-device speech-to-text), or share-to-app from anywhere
- Natural language parse: "pay electricity bill Friday 5pm" → task + due date + reminder
- Properties: title, notes, due date/time, reminder(s), priority (low/med/high), domain, person, repeat, sub-tasks, attachments (from Vault)
- Views: Today (default home tab), Upcoming (7-day), by Domain, by Person, Completed
- Today view ordering: overdue → timed items chronological → ATC payments by due date → anytime tasks by priority

## 3.2 Overload Shield (signature feature)
- Each task gets a duration estimate (default 30 min, user-adjustable)
- Day capacity from user's set working window (e.g., 8 hours)
- Adding a task to a day that exceeds ~100% capacity → **soft block:** "Monday is already full (6.5h of 6h). Move something, or add anyway?"
- Weekly heatmap: which days are overloaded
- Never blocks ATC payment tasks (bills don't negotiate) — they count toward load but always insert

## 3.3 Goals (P1)
- Goal = target + deadline + linked recurring tasks ("Learn Flutter — 3 lessons/week")
- Progress = completion rate of linked tasks
- Monthly review prompt: keep / adjust / drop each goal

---

# 4. 💰 Money (P0 light, P1 full)

## 4.1 MVP scope (P0)
- Expense log: auto-entries from ATC payment completions + quick manual add
- Categories: fixed payments auto-categorized; manual entries pick from list
- Monthly summary: total spent, by category, vs. last month
- Monthly Money Forecast (shared with ATC §2.5)

## 4.2 Full scope (P1)
- Budgets per category with progress bars and overspend alerts
- Savings goals: target + deadline → "save Rs 8,300/month to reach it"
- Receipts: every expense can link a Vault receipt
- Reports: 6-month trend, category breakdown, exportable CSV/PDF
- Multi-currency (P2)

**Not in scope (deliberate):** bank account linking — massive security/compliance burden; revisit only at scale.

---

# 5. ❤️ Health (P1)

- **Medicine reminders:** name, dose, times/day, duration, with-food flag; "Taken / Skip / Snooze" from notification; refill alert when N days remain
- **Per-person:** manage parents' and kids' medicines from one app
- **Vitals log (manual):** weight, BP, sugar — simple graphs; doctor-visit summary export (last readings + current medicines + recent reports from Vault = one PDF)
- Water & sleep tracking (simple, optional, off by default — avoid app bloat)
- Steps via phone sensors / Health Connect / HealthKit (P2)
- Medical Vault integration: prescriptions auto-suggest medicine reminders — scan prescription → "Add these 2 medicines to reminders?"

---

# 6. 👥 People (P1)

- Contact circles: Family / Close / Professional
- **Stay-in-touch nudges:** per person frequency ("Mother — every 3 days") → gentle nudge if no logged interaction; one-tap "Called ✓"
- Birthdays & anniversaries: yearly auto-tasks, reminder 3 days before (gift) + on the day
- Borrow/lend log: "Gave Ahmed Rs 5,000 on 2 Nov" → optional reminder; "Lent my drill to Bilal" → item tracking
- Each person links to their documents (kids' school papers, parents' medical records)

---

# 7. 💼 Work / Study (P1)

- Deadline tracking with milestone sub-tasks
- **Focus timer:** Pomodoro (25/5 default, configurable), daily focus-minutes stat, optional app-notification mute during focus (where OS allows)
- **AI weekly plan (premium):** user profile ("nurse, night shifts Mon–Wed") + open tasks → proposed realistic week, editable before applying
- Certificates & CV pack: Vault bundle (§1.5) pre-configured for job applications

---

# 8. 🕌 Soul (P1)

- Prayer times by location, with per-prayer notification toggle and silent/azan options
- Prayer log (optional, private): tap to mark — streaks shown gently, never shaming
- Gratitude journal: 1-line daily entry, evening prompt (optional)
- Quiet time: daily 10-minute reflection reminder
- Fully optional module — can be hidden entirely in settings; respects other faiths (configurable or off)

---

# 9. 📊 Daily Life Score (P0)

**The retention engine.** One number, 0–100, every morning.

## 9.1 Formula (weights configurable later, defaults:)
| Component | Weight | Measures |
|---|---|---|
| Tasks | 30% | yesterday's completion rate (ATC payments weigh double) |
| Payments | 25% | nothing overdue = full marks; overdue items subtract |
| Documents | 15% | no documents in expiry danger window |
| Health | 15% | medicine adherence (if active), else redistributed |
| People | 10% | no overdue stay-in-touch nudges |
| Balance | 5% | activity across ≥3 domains this week |

- Domains the user doesn't use **redistribute weight** — score never punishes unused features
- Morning notification: "Life Score 78 ↑3 — 2 things need attention today"
- Tap score → breakdown with the exact items dragging it down and one-tap fixes
- Weekly digest (Sunday evening): score trend, wins, next week's forecast

## 9.2 Tone rules
- Never guilt-based language. "2 items need attention", never "You failed 5 tasks"
- Score floor messaging: below 40 → "Heavy week? Here are the 3 highest-impact items" (triage mode)

---

# 10. 🏠 Home Dashboard (P0)

Single screen, top to bottom:
1. **Life Score** ring + delta vs yesterday
2. **Needs attention:** overdue payments, expiring documents (max 3, "see all")
3. **Today's tasks** (ATC-tagged items marked with ⚡)
4. **Money strip:** "Rs 14,500 in payments this week"
5. Quick actions: ➕ Task · 📸 Scan · 🎤 Voice

Rules: max 1 screen of content before scroll; zero ads on dashboard ever (even free tier — ads live elsewhere).

---

# 11. 👨‍👩‍👧 Family Sharing (P2 — premium)

- Household: up to 6 members, invite by link
- Shared: selected Vault folders (e.g., kids' documents), payment tasks ("either spouse can mark rent paid"), shopping/errand lists
- Private by default: everything else; sharing is per-item/per-folder opt-in
- Roles: admin (manage members) / member / view-only (e.g., elderly parent's helper)
- Delegation: assign a task to a family member → appears in their Today

---

# 12. 🔔 Notifications System (P0)

- All reminders fire **locally** (offline-safe); push used only for sync/family events
- **Notification diet** (anti-annoyance, critical for retention):
  - Morning digest (one notification: score + today's summary) instead of N separate pings
  - Timed items notify individually; everything else batches
  - Quiet hours (default 10 PM–7 AM, prayer-time aware if Soul module on)
  - Per-domain notification toggles
- Actionable notifications: "Paid ✓" / "Snooze" / "Taken ✓" without opening the app

---

# 13. 🚀 Onboarding (P0)

**Goal: first value within 2 minutes.**
1. Welcome → pick your role (student / professional / parent / business / other) — tunes defaults and examples
2. "Scan your first document" (guided — the aha moment) OR skip
3. "What do you pay monthly?" — quick-pick chips (rent, electricity, school fee…) → ATC rules created on the spot
4. Permissions asked **in context**, not upfront (camera when scanning, notifications when first reminder is set)
5. Done → dashboard already shows their forecast + first tasks

No account required to start (local mode). Signup prompted only when cloud backup/sync is wanted.

---

# 14. ⚙️ Settings & Data

- App lock (biometric/PIN), Vault separate lock, auto-lock timer
- Backup: off / Wi-Fi only / always; end-to-end encrypted (premium)
- **Export everything:** documents as ZIP of PDFs, data as CSV/JSON — no lock-in, builds trust
- Delete account: full wipe, documented, within 30 days (compliance + trust)
- Language: English + Urdu at launch (UI + voice input); RTL-ready architecture for Arabic (P2)
- Themes: light/dark/system

---

# 15. 💎 Free vs Premium Split

| Feature | Free | Premium (~$2/mo, Rs 400–500 regional) |
|---|---|---|
| Documents in Vault | 25 docs | Unlimited |
| ATC auto-rules | 3 rules | Unlimited |
| Expiry Guard | ✓ | ✓ |
| OCR field extraction | Basic (title only) | Full (amounts, dates, auto-file) |
| Cloud backup (E2E encrypted) | — | ✓ |
| Share-safe expiring links | — | ✓ |
| AI weekly plan | — | ✓ |
| Family sharing | — | ✓ (P2) |
| Multi-device sync | — | ✓ |
| Ads (outside dashboard) | Yes, minimal | None |

Conversion drivers: document limit + backup fear ("what if I lose my phone?") + ATC convenience.

---

# 16. 📋 Build Order (Groomed MVP Backlog)

**MVP = P0 (target ~3 months, 2 devs):**
1. Scan → OCR → Vault with folders/people/search (§1.1–1.3)
2. Expiry Guard (§1.4)
3. Tasks + Today view + voice add (§3.1)
4. ATC: monthly payments engine + bill pattern learning (§2.3–2.5)
5. Money light: auto expense log + forecast (§4.1)
6. Life Score v1 (tasks + payments + documents only) (§9)
7. Dashboard, onboarding, notifications diet, app lock (§10, 12, 13)

**V2 (P1):** Health, People, Work/Study, Soul, Goals, full Money, Emergency Card, appointments OCR, sharing links
**V3 (P2):** Family sharing, AI weekly plan, steps/HealthKit, multi-currency, Arabic

---

*End of specification — LifeOS v1.0 groomed feature set.*
