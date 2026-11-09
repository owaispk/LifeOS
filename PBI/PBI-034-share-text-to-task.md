# PBI-034 — Share Text to Task (WhatsApp/SMS → task)

| Field | Value |
|---|---|
| Epic | E3 ATC / E2 Mind |
| Priority | P0 (post-MVP) |
| Story Points | 3 |
| Spec refs | Features §3.1 (quick add), §2.1 (ATC principles — propose, never silently create) |
| Depends on | PBI-010 (NL parser + preview chips), PBI-003 (share-in plumbing) |
| Status | Ready |

## User Story
As a **user**, when a bill or plan arrives as a WhatsApp/SMS message, I want to share that text straight to LifeOS and get a ready-made task, so I never retype what's already on my phone.

## Description
- LifeOS registers as a **share target for plain text** (Android `ACTION_SEND text/plain`, iOS share extension) alongside the existing image/PDF share-in from PBI-003.
- Shared text opens the **existing new-task sheet pre-filled** with the text, live-parsed by the PBI-010 NL parser — same preview chips (📅 date, ⏰ time, ‼ priority, domain), same editing, same save path (a timed task gets its default reminder). Nothing is ever created without the user tapping Save (ATC principle).
- **Long shared text** (forwarded messages): the title is the first meaningful line clipped to the title limit; the full text goes into the task's notes so nothing is lost. Parsing runs over the whole text (dates/amounts are often in the middle).
- **Amount hint:** when the parser finds an amount ("Rs 4,520", "PKR 4520"), the sheet shows an amount chip; the saved task carries it in notes and the money domain is pre-selected. (A one-tap "also log as expense" is deliberately out of scope — PBI-018's flow stays the single way to log expenses.)
- Works when the app is **cold-started by the share** and when it's already running (same two paths the file share-in already handles).
- If App Lock (PBI-024) is on, the lock screen comes first; the shared text survives unlock.
- Mixed shares (text + image) are treated as a document share (existing PBI-003 flow wins); text-only goes to the task sheet.
- Urdu/Roman-Urdu text parses with the existing PBI-010 rules; the sheet is EN/UR localised already.
- Privacy: shared text is never logged (PBI-030 scrubber rules apply); it exists only in the sheet until saved or discarded.

## Acceptance Criteria
1. Sharing "Electricity bill Rs 4,520 due 15 Nov" from another app opens the new-task sheet with title "Electricity bill", a 📅 15 Nov chip, an amount chip, domain money — and nothing is saved until the user taps Save.
2. The flow works both when LifeOS was closed (cold start) and when it was in the background, on Android. iOS ships if the share extension is in place this sprint, otherwise it is split to a follow-up PBI at planning — the Dart flow must be platform-agnostic either way.
3. A multi-line forwarded message produces a sensible single-line title, the full text in notes, and parses a date found mid-text.
4. With App Lock on, unlock comes first and the pre-filled sheet appears after unlock with the text intact.
5. Sharing text plus an image triggers the existing document-capture flow, not the task sheet.
6. Dismissing the sheet discards the text completely (nothing persisted, nothing logged).
7. Parser behaviour is unchanged for existing inputs (the PBI-010 suite still passes untouched).

## Grooming Notes
- `IntentShareInbox._map` in `lib/features/capture/platform/capture_platform.dart` currently keeps only `SharedMediaType.image/file`. Add a parallel `incomingText` surface to the `ShareInbox` interface mapping `SharedMediaType.text` (and `url`), with the fake updated for tests. Mixed-share arbitration (AC5): if any image/file is present, the text is ignored.
- AndroidManifest gains `ACTION_SEND` with `text/plain` on the existing share activity. iOS: a share extension target — the known heavy part and the reason AC2 allows the split.
- The router listener that today sends shared files to capture gains a text branch → new-task sheet with `initialText`. The sheet and chips need no changes beyond accepting pre-filled text (PBI-010's live parse already handles typing).
- Amount chip: a small `Rs|PKR|₨ [\d,]+` matcher in the parser's span model, same pattern as the existing priority/domain matchers; test alongside the 44 existing parser cases.
- Smallest PBI of the three — good sprint filler, and a good first PBI for validating the new-PBI workflow post-MVP.
