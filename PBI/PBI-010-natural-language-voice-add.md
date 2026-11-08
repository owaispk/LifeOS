# PBI-010 — Natural-Language Quick Add & Voice Capture

| Field | Value |
|---|---|
| Epic | E2 Mind (Tasks) |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §3.1; UI flow §2.4, M3 |
| Depends on | PBI-009 |
| Status | Ready |

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
