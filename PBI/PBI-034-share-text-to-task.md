# PBI-034 — Share Text to Task (WhatsApp/SMS → task)

| Field | Value |
|---|---|
| Epic | E3 ATC / E2 Mind |
| Priority | P0 (post-MVP) |
| Story Points | 3 |
| Spec refs | Features §3.1 (quick add), §2.1 (ATC principles — propose, never silently create) |
| Depends on | PBI-010 (NL parser + preview chips), PBI-003 (share-in plumbing) |
| Status | Done (Android). iOS share extension split out — see below. Device QA pending |

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

## Dev & QA Notes (2026-11-10)

Code:
- `features/capture/platform/capture_platform.dart`: a share now arrives as one `SharedIn` — files **or** text, never both. `mapSharedMedia` does the arbitration in one place (AC5) and is unit-tested directly, so the rule is not hidden behind the plugin.
- `features/capture/share_in_listener.dart`: the text branch. The listener wraps `MaterialApp`'s builder and so sits *above* the Navigator; the sheet is opened on the router's navigator instead, from a microtask rather than a post-frame callback (nothing schedules a frame when the app is idle).
- `features/tasks/domain/task_title.dart` (new, pure Dart): `titleFrom` — the one place words recognised by the parser are taken out of a title, now shared by the live preview and by shared text; `sharedTaskTitle` (first meaningful line, clipped at a word boundary, 80 chars); `taskNotes`.
- `features/tasks/domain/nl_parser.dart`: `ParsedPart.amount`. `Rs|Rs.|PKR|INR|₨`, optional `/-`, thousands separators. An amount means the money domain on its own, since "PKR 4520" carries no hint word. "due", "due on" and "due by" join the glue words a recognised date takes with it.
- `features/tasks/ui/new_task_sheet.dart`: `initialText`. Parsing runs over the whole message, the title comes from the first line.
- `AndroidManifest.xml`: `ACTION_SEND` + `text/plain` on the existing share activity.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: sharing "Electricity bill Rs 4,520 due 15 Nov" opens the sheet titled "Electricity bill" with 📅, 💰 Rs 4,520 and a money chip. The task table is empty until **Add** is tapped; after it, one task due 15 Nov, domain money, amount in notes. |
| 2 | ⚠️ Android only | Widget: both paths — a share while the app runs, and `initial()` on a cold start (app restarted on the same database). The Dart flow is platform-agnostic: it reads `SharedIn`, not an Android intent. **iOS is not done** — see below. |
| 3 | ✅ | Unit + widget: a 3-line forwarded school message titles from line 1 ("Reminder from school"), keeps all 3 lines in notes, and takes its due date (20 Nov) and amount (Rs 12,000) from line 2. A long single line clips at a word boundary with "…". |
| 4 | ✅ | Widget: App Lock on, a failing authenticator keeps the lock screen up; a share arriving then shows no sheet. After **Unlock** passes, the sheet appears with "Pay the school fee" intact. |
| 5 | ✅ | Unit on `mapSharedMedia`: text alone → text; text + image → one file and no text; a shared link → text. The existing PBI-003 PDF share test still goes to capture. |
| 6 | ✅ | Widget: dismissing the sheet leaves the task table empty. The text is held in one `String?` field in the listener and dropped as soon as the sheet opens; nothing on this path writes to the log. |
| 7 | ✅ | The 101 existing task tests pass untouched, including the 44 parser cases. A bare number is still not an amount ("buy 6 eggs", "call at 5"), and text with no amount parses exactly as before. |

`flutter analyze`: no issues · full suite `flutter test`: **577/577 passed** (20 new).

**iOS split out (AC2).** The Dart side is ready — only the native share extension target is missing, which is the heavy part AC2 anticipated. It needs its own PBI: an iOS share extension, the App Group the plugin wants, and a device pass on a Mac. Nothing in the Dart flow has to change for it.

**Not verified:** no device pass yet. The Android manifest filter, the real share sheet, and a cold start from a WhatsApp share all need a phone — they belong in the next device QA session alongside PBI-033 and the PBI-003/004 scanning rework.

**Share-in crash guard (ported from the parallel PBI-034 branch, `f1ffba4`).** A share whose content:// file LifeOS isn't allowed to read crashed the app inside `receive_sharing_intent` (`SecurityException` from an unguarded `openInputStream`). `MainActivity` now checks each shared content:// URI before the plugin sees the intent (in `onCreate` before `super`, and in `onNewIntent`): unreadable items are dropped from `SEND_MULTIPLE`; a `SEND`, or a multi-share with nothing readable, is ignored and the app simply opens. Text shares carry no URI and are unaffected. Verified on the Android emulator on that branch (cold start and background); still to recheck with this implementation on a phone.
