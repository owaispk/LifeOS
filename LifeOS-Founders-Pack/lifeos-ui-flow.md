# LifeOS — UI / Screen Flow Document

**Version:** 1.0 · **Date:** 2026-11-08
**Companion to:** `lifeos-features-spec.md`
**Design language:** Material 3 (Flutter), light/dark themes, large touch targets, minimal chrome. Urdu + English, RTL-ready.

---

# 1. Navigation Map (Global)

## 1.1 Primary Navigation — Bottom Bar (5 tabs)

```
┌─────────────────────────────────────────────────┐
│                  (screen content)               │
│                                                 │
│                    [ ➕ FAB ]                    │
├─────────┬─────────┬─────────┬─────────┬─────────┤
│  🏠     │  ✅     │  📂     │  💰     │  ⋯      │
│  Home   │  Tasks  │  Vault  │  Money  │  More   │
└─────────┴─────────┴─────────┴─────────┴─────────┘
```

- **FAB (center-docked, expandable):** tap → radial menu: ➕ Task · 📸 Scan · 🎤 Voice · 💸 Expense
- **More tab:** Health, People, Work/Study, Soul, ATC Rules, Settings — P1 domains live here until used often (then user can pin one to replace Money in the bar — customizable bottom bar, P1)

## 1.2 Full Screen Inventory

```
App Launch
├── 0.1 Splash / App Lock (biometric)
├── 0.2 Onboarding (first run only, 4 steps)
│
├── 1. HOME (dashboard)
│   ├── 1.1 Life Score Detail
│   └── 1.2 Needs Attention (full list)
│
├── 2. TASKS
│   ├── 2.1 Today (default)
│   ├── 2.2 Upcoming
│   ├── 2.3 Task Detail / Edit
│   ├── 2.4 New Task (sheet)
│   └── 2.5 Overload Shield dialog
│
├── 3. VAULT
│   ├── 3.1 Vault Home (folders + people)
│   ├── 3.2 Folder / Person view
│   ├── 3.3 Document Viewer
│   ├── 3.4 Scan Flow (camera → crop → classify → confirm)
│   ├── 3.5 Search results
│   ├── 3.6 Expiring Soon
│   └── 3.7 Share sheet (file / safe link / bundle)
│
├── 4. MONEY
│   ├── 4.1 Month Overview
│   ├── 4.2 Monthly Forecast
│   ├── 4.3 Expense list / detail
│   └── 4.4 Add Expense (sheet)
│
├── 5. MORE
│   ├── 5.1 ATC Rules manager
│   ├── 5.2 Health (P1) · 5.3 People (P1) · 5.4 Work/Study (P1) · 5.5 Soul (P1)
│   ├── 5.6 Settings (lock, backup, language, notifications, export)
│   └── 5.7 Premium / upgrade
│
└── Modals (reachable anywhere)
    ├── M1 ATC proposal dialog ("Create this monthly task?")
    ├── M2 Payment completion chain sheet
    ├── M3 Voice capture overlay
    └── M4 Quick scan (from FAB)
```

**Depth rule:** nothing lives more than **2 taps** from the bottom bar. Core loop actions (scan, add task, mark paid) are **1 tap** from anywhere via FAB or notification actions.

---

# 2. Screen-by-Screen Specification

## 0.2 Onboarding (4 steps, skippable after step 1)

**Step 1 — Role picker**
- Full-screen, warm illustration, headline: *"Run your whole life from one app"*
- 5 large cards: Student / Professional / Parent / Business owner / Just me
- Selection tunes copy and default ATC suggestions throughout; no account asked

**Step 2 — First scan (the aha moment)**
- *"Scan any document — a bill, your ID, anything"* → opens camera with ghost-frame overlay
- After scan: show the magic — auto-crop animation → detected type chip ("Looks like an electricity bill") → extracted amount/due date appear as filled fields
- Skip link bottom-left (small, available but not emphasized)

**Step 3 — Monthly payments quick-pick**
- *"What do you pay every month?"* — chip grid: Rent · Electricity · Gas · Internet · School fee · Mobile · Installment · + Custom
- Tapping a chip expands inline: amount + day-of-month (2 fields only)
- Each completed chip shows ⚡ "Auto-reminder on"

**Step 4 — Done**
- Confetti-lite. Shows their **first Monthly Forecast** ("Your November: Rs 54,500 across 4 payments") → button: *"See my dashboard"*
- Notification permission requested here, in context: *"Want reminders before due dates?"*

---

## 1. HOME — Dashboard

**Layout (top → bottom):**

```
┌──────────────────────────────────┐
│  Salam, Owais 👋        🔔  👤   │  ← greeting, notif center, profile
│                                  │
│        ╭────────╮                │
│        │   78   │  ↑3            │  ← Life Score ring (animated fill,
│        ╰────────╯                │     color: red<40 amber<70 green≥70)
│   "2 things need attention"      │  ← tappable → 1.1 breakdown
│                                  │
│  ⚠ NEEDS ATTENTION               │
│  ┌──────────────────────────┐    │
│  │ 🔴 Electricity bill       │    │  ← swipe right = done/paid
│  │    due tomorrow · Rs 4,850│    │     tap = detail
│  │ 🟠 Passport (Ali)         │    │
│  │    expires in 28 days     │    │
│  └──────────────────────────┘    │
│                                  │
│  TODAY · 5 tasks                 │
│  ○ ⚡ Pay school fee  Rs 12,000  │  ← ⚡ = ATC-created
│  ○ Call electrician   4:00 PM    │
│  ○ Review CV              ⋯      │
│                                  │
│  💰 Rs 14,500 payments this week │  ← strip, tap → Money
│                                  │
│            [ ➕ ]                │
└──────────────────────────────────┘
```

**Interactions:**
- Score ring animates on open (0 → value, 600ms) — the daily dopamine moment
- Needs Attention capped at 3 items + "See all" → screen 1.2
- Pull-to-refresh recalculates score
- Empty states: new user with nothing → friendly prompts ("Scan your first document 📸") not blank space

## 1.1 Life Score Detail
- Big ring + 7-day sparkline
- Component bars: Tasks 30% ▓▓▓▓░ · Payments 25% ▓▓▓▓▓ · Documents 15% ▓▓░░░ …
- Below: *exact* items dragging score down, each with a one-tap fix button ("Renew reminder set ✓")
- Weekly digest card (Sundays): wins + next week forecast

---

## 2. TASKS

### 2.1 Today (default tab inside Tasks)
- Segmented control top: **Today · Upcoming · Domains**
- Sections in order: **Overdue** (red header) → **Timed** (chronological with time labels) → **Payments ⚡** (by due date) → **Anytime** (by priority)
- Task row anatomy: `○ checkbox · title · chips(⚡/domain/person) · time/due · 📎 if attachment`
- Swipe right = complete (haptic + satisfying check animation) · Swipe left = snooze menu (tonight / tomorrow / pick)
- Completing an ATC payment task → opens **M2 completion chain sheet** (see Modals)

### 2.3 Task Detail
- Title (inline edit), notes, due + reminder rows, priority selector, domain + person chips
- **Source line for ATC tasks:** "⚡ Created from: K-Electric bill scanned 12 Oct" → tappable → opens that document
- Attachments strip (thumbnails from Vault) + "Attach from Vault"
- Sub-tasks checklist
- Footer: Delete · Skip this cycle (ATC tasks) · Mute this rule (ATC tasks)

### 2.4 New Task (bottom sheet, not full screen)
- One smart text field: natural language ("pay internet Friday 5pm") with live parse preview chips underneath (📅 Fri 5:00 PM ✓)
- 🎤 mic button inside the field
- Expandable "More options" for the full form — default stays minimal

### 2.5 Overload Shield dialog
- Appears on save when day > 100% capacity:
- *"Monday is already full (6.5h of 6h)"* + mini bar chart of the week
- Buttons: **Move to Tuesday (suggested)** · Pick a day · Add anyway
- Suggested day = nearest day under 70% load

---

## 3. VAULT

### 3.1 Vault Home
```
┌──────────────────────────────────┐
│  🔍 Search documents…            │
│                                  │
│  PEOPLE                          │
│  (Me) (Ayesha) (Ali) (Ammi) (+)  │  ← avatar chips, horizontal
│                                  │
│  ⏰ EXPIRING SOON (2)      see → │
│  [Passport·Ali·28d] [Visa·90d]   │  ← horizontal cards, urgency color
│                                  │
│  FOLDERS                         │
│  🪪 Identity        12 docs      │
│  🎓 Education        8 docs      │
│  🏥 Medical         15 docs      │
│  🧾 Bills & Receipts 44 docs     │
│  🏠 Property         3 docs      │
│  🚗 Vehicles         5 docs      │
│  ➕ New folder                   │
│                                  │
│           [ 📸 Scan ]            │  ← persistent primary action
└──────────────────────────────────┘
```
- Vault may demand its own biometric unlock on entry (setting)
- Screenshots blocked inside Vault screens (if enabled)

### 3.3 Document Viewer
- Full-bleed document, pinch-zoom, page dots for multi-page
- Info panel (swipe up): type, person, extracted fields (editable), expiry with alert ladder shown, tags, "linked tasks" (the bill's payment task)
- Action bar: Share · Download PDF · Edit fields · Move · Archive · Delete (soft delete, 30-day trash)

### 3.4 Scan Flow (4 quick screens)
1. **Camera:** ghost frame, auto edge highlight, auto-capture when steady (toggle), batch counter top-right, flash/import buttons
2. **Crop/enhance:** draggable corners, mode chips (Original/Doc/Grayscale), "Add page" for multi-page
3. **Classify (the magic screen):** document preview with detected type chip + extracted fields sliding in as they're read — *"K-Electric Bill · Rs 4,850 · due 14 Nov"* — each field editable; person selector; folder auto-chosen with override
4. **Confirm:** single button *"Save to Vault"*; if a due date was found → inline toggle, pre-ON: *"⚡ Create payment task for 14 Nov"*

Total target time: **under 15 seconds** scan-to-saved.

### 3.6 Expiring Soon
- Sorted by days remaining; urgency coloring (red ≤7d, amber ≤30d, grey beyond)
- Each row: renew flow button → "Mark renewed → scan new document" wizard (old doc auto-archived)

### 3.7 Share sheet
- Three options with trust labels:
  - **Send file** (standard OS share)
  - **Safe link 🔒** — expiry picker (1h / 24h / 7d), optional PIN, watermark toggle → copies link; active links listed with revoke buttons
  - **Bundle** — multi-select docs → merged "Application Pack.pdf"

---

## 4. MONEY

### 4.1 Month Overview
- Big number: spent this month + vs-last-month delta arrow
- Donut by category (fixed payments pre-colored)
- Recent expenses list (receipt thumbnail if linked)

### 4.2 Monthly Forecast
- Calendar strip with payment dots on due days
- List: each payment with amount, status chip (Upcoming / Paid ✓ / Overdue 🔴)
- Header: "Rs 61,500 total · Rs 23,000 paid · Rs 38,500 remaining"
- Salary-aware mode on → timeline starts at salary date, "41% of income goes to fixed payments" insight line

---

## 5. MORE

### 5.1 ATC Rules Manager
- List of rules grouped by type (Bills · Fees · Fixed · Appointments)
- Rule row: name, cadence ("~12th monthly"), last/next run, pause toggle
- Rule detail: edit fields, history ("created 6 tasks, 6 paid on time ✓"), mute/delete
- Header stat: *"⚡ ATC created 14 tasks for you this month"* — makes the invisible value visible

### 5.6 Settings (grouped)
- **Security:** app lock, Vault lock, auto-lock timer, screenshot block
- **Backup & sync:** off / Wi-Fi / always, E2E badge, last backup time, restore
- **Notifications:** morning digest time, quiet hours, per-domain toggles
- **Language:** English / اردو (instant switch, no restart)
- **Data:** export all (ZIP/CSV/JSON), trash, delete account
- **Premium:** plan status, manage

---

# 3. Global Modals

## M1 — ATC Proposal dialog
> ⚡ **New pattern detected**
> "Your electricity bill usually arrives the 10th–14th. Create a monthly reminder?"
> [ Yes, remind me ] [ No thanks ]
- Max 1 proposal per day (anti-annoyance); others queue

## M2 — Payment Completion Chain (bottom sheet, after checking off a payment)
```
✓ School fee — Rs 12,000 paid
📎 Attach receipt?   [📸 Scan] [🖼 Gallery] [Skip]
→ then: "Filed in Vault · Logged in Money · Score +2" (3 stacked
  micro-confirmations animate in — the one-tap-four-results moment)
```

## M3 — Voice Capture overlay
- Full-screen mic with live waveform + live transcription (Urdu/English auto)
- Parse preview: *"Pay electricity bill → Friday"* chips → [Create ✓]

---

# 4. Notifications (as UI surfaces)

| Notification | Actions (no app open needed) |
|---|---|
| ☀️ Morning digest: "Score 78 · 5 tasks · 1 bill due" | tap → Home |
| 💸 "Electricity due tomorrow — Rs 4,850" | [Paid ✓] [Snooze] |
| ⏰ "Passport (Ali) expires in 30 days" | [Set renewal task] [Dismiss] |
| 💊 "Metformin — 8:00 PM" (P1) | [Taken ✓] [Skip] [10 min] |
| ⚡ ATC proposal | [Yes] [No] |

Lock-screen privacy: generic titles when app lock is on ("A payment is due tomorrow").

---

# 5. Design System Notes

- **Type scale:** large readable defaults (16sp body) — audience includes parents/elders
- **Domain colors:** Mind indigo · Money green · Health red · People amber · Work blue · Soul teal · Vault slate — used as accents/chips only, never full-screen floods
- **Score colors:** <40 red, 40–69 amber, ≥70 green
- **Motion:** check-off tick, score ring fill, scan auto-crop snap — 3 signature animations max; everything else instant
- **Offline indicator:** subtle cloud-off icon in app bar; absolutely no blocking "no internet" walls
- **Accessibility:** full TalkBack/VoiceOver labels, 48dp touch targets, dynamic type support
- **Empty states:** every list has an illustrated empty state with one action button — never a blank screen

---

# 6. Core User Journeys (click-paths)

1. **Scan a bill → auto task:** FAB 📸 → camera → confirm classify → "Save to Vault" (⚡ toggle on) → done. *4 taps, ~15s.*
2. **Pay day:** notification [Paid ✓] → M2 sheet → scan receipt → auto-filed/logged. *3 taps.*
3. **Find document in crisis:** Vault → search "passport" → viewer → Share → Safe link 24h. *5 taps.*
4. **Monthly planning:** 1st of month digest → Forecast screen → review → done. *2 taps.*
5. **New fee cycle:** scan voucher → ATC proposes monthly rule → [Yes]. *3 taps, runs forever.*

---

*End of UI/Screen Flow — pairs with `lifeos-features-spec.md` §16 build order.*
