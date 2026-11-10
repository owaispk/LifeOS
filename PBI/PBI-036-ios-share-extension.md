# PBI-036 — iOS Share Extension ("Share to LifeOS" on iPhone)

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P1 (post-MVP, iOS parity) |
| Story Points | 5 |
| Spec refs | Features §1.1 (import), §3.1 (quick add); UI flow §3.4 |
| Depends on | PBI-003 (share-in plumbing), PBI-034 (the text branch) — **a Mac with Xcode** |
| Status | Ready (blocked: no iOS toolchain on the dev machine) |

## User Story
As an **iPhone user**, I want "LifeOS" to appear in the iOS share sheet so I can send a bill photo, a PDF or a WhatsApp message straight into LifeOS, exactly as Android users already can.

## Description

**Nothing shared from another app reaches LifeOS on iOS today** — not a photo, not a PDF, not text. `receive_sharing_intent` needs a native Share Extension target on iOS, and the project has none: no extension, no App Group, no entitlements file. The Android side of both PBI-003 and PBI-034 works; this is the missing half.

This PBI is **native plumbing only**. No Dart behaviour changes, no new screens, no new strings. What arrives is already handled: `mapSharedMedia` turns the payload into a `SharedIn` and `ShareInListener` routes files to capture and text to the new-task sheet. Those are platform-agnostic by construction (PBI-034 made sure of it), and they must come out of this PBI untouched.

### The native work
- A **Share Extension** target in `ios/Runner.xcodeproj`, with `ShareViewController` inheriting `RSIShareViewController`.
- An **App Group** (e.g. `group.com.lifeos.app`) with the App Groups capability on **both** targets, and a `CUSTOM_GROUP_ID` user-defined build setting on both. The extension and the app have separate sandboxes; the group is the only way shared files cross between them.
- The extension's `Info.plist` activation rules, chosen to match what LifeOS can actually accept rather than everything iOS offers:
  - `NSExtensionActivationSupportsText` — PBI-034.
  - `NSExtensionActivationSupportsWebURLWithMaxCount` 1 — a shared link arrives as text.
  - `NSExtensionActivationSupportsImageWithMaxCount` — batch photo import (PBI-003).
  - `NSExtensionActivationSupportsFileWithMaxCount` — PDFs.
  - **Not** `Movie`. LifeOS has nothing to do with a video, and offering to receive one only to drop it is worse than not appearing in the sheet.
- `CFBundleURLTypes` with `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` on Runner, and `AppGroupId` in both plists.
- `NSPhotoLibraryUsageDescription` — Apple rejects builds that touch the photo library without one.

### What this is not
- No change to `ShareInListener`, `mapSharedMedia`, `SharedIn`, the capture flow or the new-task sheet. If any of them needs editing, something has gone wrong — raise it rather than working around it.
- Not the iOS home-screen widget. PBI-033 split WidgetKit out for the same "no Mac" reason; that is a **separate PBI still to be written**, and sharing a sprint with this one only because both need the same machine.

## Acceptance Criteria
1. LifeOS appears in the iOS share sheet for a photo, a PDF and selected text, and does **not** appear for a video.
2. Sharing a photo or a PDF opens the capture confirm step with `source = share_in`, both when LifeOS was closed and when it was already running — the same two paths Android covers.
3. Sharing text opens the new-task sheet pre-filled and parsed, with the PBI-034 chips; a multi-line forwarded message titles from its first line and keeps the whole text in notes.
4. A mixed share (text plus an image) goes to capture, not the task sheet — the same arbitration `mapSharedMedia` already applies on Android.
5. With App Lock on, the lock screen comes first and the shared content survives unlock (PBI-034 AC4, now on iOS).
6. Dismissing the sheet or the confirm step discards everything; nothing is written and nothing is logged.
7. **No Dart file changes.** The diff is `ios/` and project configuration only, and the full existing suite passes untouched.
8. A shared file lands in the App Group container and is copied into the Vault directory on save; nothing is left behind in the group container afterwards.

## Out of Scope
- iOS WidgetKit (PBI-033's follow-up, its own PBI).
- Share **out** from LifeOS — already works through `share_plus` (PBI-007).
- iOS-specific UI polish, App Store submission, TestFlight.
- Video or audio sharing.

## Grooming Notes
- `receive_sharing_intent` 1.9.0 is already a dependency and already does the Dart side. Its README's iOS section is the authority on the target setup; follow it rather than inventing a layout.
- The plugin is made available to the extension through Swift Package Manager (it provides `RSIShareViewController`). The common failure is "No such module 'receive_sharing_intent'" in the extension target — the README has a section on exactly that.
- `NSExtensionMainStoryboard` is `MainInterface`; the extension point identifier is `com.apple.share-services`.
- Two App Group ids may be needed if build flavours are ever added; one is enough today.
- **The honest blocker:** none of this can be written, built or tested without a Mac with Xcode. The file edits could be typed blind, but an Xcode target is project-file surgery that is unreviewable and unbuildable here, and a half-made target is worse than none. This PBI should be picked up on a Mac, in one sitting, and verified on a real iPhone — the simulator's share sheet does not exercise the App Group the way a device does.
- Sequence it with PBI-033's iOS widget PBI and the outstanding iOS device QA, so the Mac is only borrowed once.
