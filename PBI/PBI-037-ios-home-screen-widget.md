# PBI-037 — iOS Home-Screen Widget (WidgetKit)

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P1 (post-MVP, iOS parity) |
| Spec refs | Features §9 (Life Score), §10 (Home dashboard), §12 (notification diet) |
| Story Points | 8 |
| Depends on | PBI-033 (the widget, its snapshot and deep links) — **a Mac with Xcode** |
| Status | Ready (blocked: no iOS toolchain on the dev machine) |

## User Story
As an **iPhone user**, I want the LifeOS widget on my home screen — Life Score, today's tasks, the next payment — the same glance Android users already get.

## Description

PBI-033 shipped the widget on Android and made the iOS half an explicit scope decision, not an oversight: *"Android only, per the grooming note — iOS WidgetKit split out as a follow-up PBI (no iOS toolchain on the dev machine)."* This is that PBI.

**Most of the work is already done and must not be redone.** `widget_snapshot.dart` builds one platform-neutral JSON — score, up to 4 task lines, the payment line, counts, EN/UR text, the details-on/off flag, and a precomputed **tomorrow** variant. The natives only render. That contract is what makes this PBI small, and keeping it is the main constraint: a SwiftUI view that computes anything is a bug, because the widget and the dashboard would be able to disagree.

### Native (the bulk)
- A **Widget Extension** target in `ios/Runner.xcodeproj`, SwiftUI, with `systemSmall` and `systemMedium` families.
  - **small** = score ring + counts. **medium** = the full layout. This matches the sizes PBI-033 already specifies.
- An **App Group** shared with Runner — the same mechanism PBI-036 needs for the share extension, and the two should agree on one group id rather than inventing two.
- A `TimelineProvider` that reads the snapshot from the group container.
- Deep links via SwiftUI `Link` / `widgetURL`, reusing the existing `lifeos://` table in `core/router/deep_links.dart`. No new routes.

### Dart (small, but real — unlike PBI-036)
This is the one place this PBI differs from the share-extension one, and it was found by reading the code rather than assumed:

- `HomeWidgetGateway.push` currently calls `HomeWidget.updateWidget(androidName: …)` only. It needs `iOSName:` as well.
- `HomeWidget.setAppGroupId(...)` must be called at startup, or nothing on iOS can read what the app writes.
- `cancelScheduledWidgetUpdates` / `scheduleWidgetUpdates` are the **Android** midnight mechanism. iOS has no equivalent: WidgetKit decides when to refresh from the timeline the extension returns. So the midnight roll is handled by the `TimelineProvider` emitting a second entry at the date change, fed by the **tomorrow** variant the snapshot already carries. Same data, different delivery.

`widget_snapshot.dart` itself must not change. If it does, Android's rendering is at risk and that is not what this PBI is for.

## Acceptance Criteria
1. The widget can be added on iOS in small and medium sizes and shows the current Life Score, today's tasks (max 4, ATC first) and the next payment, matching the in-app dashboard.
2. Completing a task in the app updates the widget within seconds, with no manual refresh.
3. The widget rolls over at midnight without the app being opened, from the tomorrow variant already in the snapshot — via the WidgetKit timeline, not an Android-style scheduled update.
4. Tapping the ring, a task row and the payment line each deep-link to the right screen, including from a cold start, and land on the target after unlock when App Lock is on.
5. With "Show details on widget" off, only the ring and counts appear — no task titles, no amounts. The same flag that governs Android governs iOS.
6. Light and dark both render correctly at both sizes; Urdu renders RTL.
7. A widget write never blocks the UI and never crashes the app when the widget host is unavailable (one log entry per failure), as on Android.
8. `widget_snapshot.dart` is unchanged, the Android widget still behaves exactly as before, and the full existing suite passes.

## Out of Scope
- Lock Screen and StandBy widgets (`accessory*` families), Live Activities, and `systemLarge`.
- Interactive widgets — ticking a task off from the widget is out of scope on **both** platforms (PBI-033 says so, and the reasoning has not changed).
- The iOS share extension (PBI-036) — a separate PBI that happens to need the same machine and the same App Group.
- App Store submission, TestFlight.

## Grooming Notes
- `home_widget` 0.10.0 is already a dependency and already carries the iOS side; its documentation site covers the Widget Extension setup. Its own `example/ios` has a working target (`HomeWidgetExample`) worth reading before starting.
- Agree the App Group id with PBI-036 **before** either is built. Two targets sharing one group is normal; two groups invented separately is a day lost.
- The Kotlin provider (`LifeOsWidgetProvider`) is the reference for what to render — it reads the same JSON keys. Port its layout decisions, not its code.
- Android picks 2×2 vs 4×2 by measured width; iOS gets the family directly from WidgetKit, which is simpler — do not port the width heuristic.
- RTL: SwiftUI follows the environment layout direction, but the widget process does not inherit the app's in-app language choice (PBI-025). The language is already in the snapshot — use that, not the system locale, or an Urdu user with an English phone gets the wrong direction.
- **The honest blocker:** a Mac with Xcode, and a real iPhone to verify on. WidgetKit timelines in particular behave differently in the simulator, so AC3 cannot be trusted there.
- Do this in the same sitting as PBI-036 and the outstanding iOS device QA, so the Mac is borrowed once.
