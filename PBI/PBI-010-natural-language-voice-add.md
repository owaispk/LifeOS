# PBI-010 — Natural-Language Quick Add & Voice Capture

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §3.1; UI flow §2.4, M3 |
| Depends on | PBI-009 |
| Status | Done (voice on a real phone's recogniser still to be tried by hand) |

## User Story
As a **user**, I want to type or say "pay electricity bill Friday 5pm" and get a correct task with a reminder.

## Description
- A pure-Dart NL parser that extracts: date words (today, tomorrow, weekdays, "next Monday", "on 14th", "14 Nov"), time ("5pm", "17:00", "morning/evening"), priority ("urgent", "!"), and domain hints ("bill/pay" → money)
- English first. Common Urdu/Roman-Urdu date words are supported (aaj, kal, parson, Jumma…).
- Live parse-preview chips under the field (📅 Fri 5:00 PM ✓). Tapping a chip removes it.
- 🎤 mic inside the field plus the full-screen voice overlay (M3), using on-device speech-to-text (`speech_to_text`), English + Urdu
- Microphone permission is requested in context

## Acceptance Criteria
1. "pay electricity bill Friday 5pm" produces the title "Pay electricity bill", the next Friday at 17:00, domain money, and a reminder at the due time.
2. At least 30 parser test cases pass, including relative dates across month/year boundaries.
3. When nothing parses, the whole text becomes the title with no due date. The parser never throws.
4. The voice overlay shows live transcription and the same preview chips. Tapping Create saves the task.
5. Voice works offline where the device's on-device recogniser is available. Otherwise a friendly message appears; there is no crash.

## Grooming Notes (Sprint 6, 2026-11-09)
**Parser:** `lib/features/tasks/domain/nl_parser.dart`, pure. `parseTask(text, now)` returns title, due date, time, priority, domain, and the matched spans used for the chips.
- **Dates:** today/aaj; tomorrow/kal; day after tomorrow/parson; weekday names (en + Roman Urdu: peer, mangal, budh, jumerat, jumma, hafta, itwar); "next Monday" (the week after); "on 14th" / "14th" (the next date with that day of month, clamped); "14 Nov" / "Nov 14" (this year, or next year if already past); "in 3 days".
- **Time:** "5pm", "5:30 pm", "17:00", "at 5" (PM when that's still later today, else AM); morning 09:00, afternoon 15:00, evening 18:00, night 21:00 (subah/shaam/raat).
- **Priority:** "urgent", "!", "important" → high.
- **Domain:** pay/bill/rent/fee/rs → money; doctor/medicine → health; call/meet → people; document/passport/cnic → vault.
- **Title:** the leftover text, trimmed, first letter capitalised. Matched words like "on"/"at" are removed only when attached to a match.
- It never throws (a catch-all fallback returns the whole text, AC3).

**Preview chips:** under the title field in the new-task sheet: 📅 date, ⏰ time, ‼ priority, a domain dot. Tapping a chip removes that part of the parse. Saving uses the same task-service path (a timed task gets its default reminder).

**Voice:** `speech_to_text` behind a `SpeechInput` interface (with a fake in tests).
- The M3 overlay shows live words plus the same chips, and a Create button.
- Locale `en_US`, or `ur_PK` when the app language is Urdu.
- If the recogniser isn't available, the overlay says "Voice isn't available on this phone — type instead" (AC5).
- The microphone permission is requested only when 🎤 is tapped.

## Dev & QA Notes (Sprint 6, 2026-11-09)
Code:
- `lib/features/tasks/domain/nl_parser.dart`: pure, never throws.
- `ui/quick_parse.dart`: preview chips, `createFromParse`, `SpeechInput` (`speech_to_text`) and the M3 voice overlay.
- The new-task sheet parses live and has a 🎤 button.
- The ➕ → Voice quick action opens the overlay.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Unit + widget: "pay electricity bill Friday 5pm" → "Pay electricity bill", Fri 13 Nov 17:00, money, a reminder at 17:00. Chips show "Fri, 13 Nov" and "5:00 PM". |
| 2 | ✅ | **44 parser tests**: 37 table cases (relative days, weekdays, "next Monday", times, parts of day, day-of-month, month names, Roman Urdu) plus month-end, year-end and leap-year rollovers, the "next Friday" rule, priority, domains and chip removal. |
| 3 | ✅ | "buy groceries" → the whole text as the title, no date. Odd inputs ("99:99", "31st feb", emoji, "in 999 weeks") never throw. |
| 4 | ✅ | Widget with fake speech: the overlay shows the live words "call Ahmed tomorrow 6pm" and the time chip; Create saves "Call Ahmed", 9 Nov 18:00, people; the recogniser is stopped. |
| 5 | ✅ | Widget: with no recogniser, "Voice isn't available on this phone — type instead" appears, with no Create button and no crash. |

Chip removal puts the words back: "meet Friday 5pm" with the date chip removed → "Meet Friday", today at 17:00. A date the user picks by hand always beats the parse.

Found in dev: the overlay used `ref` in `dispose()`, which crashed on close. It now keeps the speech service in a field.

`flutter analyze`: no issues · full suite **457/457 passed**, identical on two runs · schema v6 migration tested from v1–v5 · device checks on the Android 17 emulator (2026-11-09).
