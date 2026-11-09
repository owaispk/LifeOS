# PBI-033 — Home-Screen Widget (Today at a glance)

| Field | Value |
|---|---|
| Epic | E6 Engagement |
| Priority | P0 (post-MVP) |
| Story Points | 8 |
| Spec refs | Features §9 (Life Score — "the retention engine"), §10 (Home dashboard), §12 (notification diet — the widget informs without nagging) |
| Depends on | PBI-009 (tasks), PBI-013 (payments), PBI-020 (Life Score), PBI-021 (dashboard) |
| Status | Ready |

## User Story
As a **user**, I want a home-screen widget showing my Life Score, today's tasks and the next payment due, so that LifeOS keeps me on track without me even opening the app.

## Description
- One resizable widget via the `home_widget` package. **Android first-class** (primary market), iOS WidgetKit small/medium as the same data with a simpler layout.
- **Content:** Life Score ring with the number · up to 4 of today's tasks (⚡ ATC payments first, then by time) with overflow "+N more" · next payment due line ("⚡ Electricity ~Rs 4,300 · Thu") · friendly empty state ("All clear today ✨").
- **Sizes (Android):** 2×2 = score ring + counts only; 4×2 = full layout. iOS small = ring + counts, medium = full.
- **Taps deep-link:** the ring → Score breakdown screen; a task row → that task; the payment line → its task; anywhere else → Home. Uses the existing GoRouter deep links.
- **Refresh:** the app pushes fresh widget data on every relevant change (task done/added, payment state, score recompute at midnight via the existing scheduler) and on app pause. No independent polling; battery-friendly.
- **Privacy:** respects App Lock (PBI-024) — a new setting "Show details on widget" (default on; auto-prompted off when App Lock is enabled). When off, the widget shows only the score ring and counts, never task titles.
- **Theming:** light/dark follows the system; matches the Flagship look (PBI-031) — dense, no decoration.
- Checking a task **off from the widget is out of scope** (interactive widgets vary wildly by launcher/OS version); the widget is a glanceable view + launcher.
- EN/UR strings; RTL layout for Urdu on Android.

## Acceptance Criteria
1. After adding the widget, it shows the current Life Score, today's tasks (max 4, ATC first) and the next payment due, matching the in-app dashboard.
2. Completing a task in the app updates the widget within seconds of the change (no manual refresh).
3. The midnight score recompute updates the widget without the app being opened (verified alongside the PBI-020 scheduler path).
4. Tapping the ring, a task, and the payment line each deep-link to the right screen, including when the app was fully killed (cold start lands on the target after unlock if App Lock is on).
5. With "Show details on widget" off, no task titles or amounts appear — only the ring and counts; enabling App Lock prompts this choice once.
6. Light and dark system themes both render correctly in 2×2 and 4×2 (screenshot check); Urdu renders RTL.
7. Widget data writes never block the UI and never crash the app if the launcher/widget host is unavailable (guarded, one log entry per failure).

## Grooming Notes
- `home_widget` = shared storage + native render: Android `RemoteViews` XML layouts (one per size), iOS a small SwiftUI WidgetKit extension. The Dart side serialises a `WidgetSnapshot` (score, up to 4 task lines, payment line, counts, flags) to JSON; natives only render, never compute.
- Build the snapshot in one place — a `widget_snapshot.dart` fed by the same providers as the Home dashboard (PBI-021), so widget and dashboard can never disagree. Unit-test the snapshot builder with the usual fakes.
- Push points: task service mutations, payment engine transitions, score recompute, app pause. Debounce (~1 s) so a batch of changes writes once.
- Midnight update rides the existing background recompute (PBI-020); if the OS deferred it, the next app open corrects the widget — acceptable.
- Deep links: `lifeos://` scheme routes already exist for notifications (PBI-012); reuse the same table.
- iOS effort is the risk; if it balloons, split iOS out as a follow-up PBI and ship Android (decide at sprint planning, not mid-sprint).
