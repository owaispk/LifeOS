# PBI-001 — Project Foundation & App Shell

| Field | Value |
|---|---|
| Epic | E0 Foundation |
| Priority | P0 (MVP) |
| Story Points | 5 |
| Spec refs | README "Recommended tech stack"; UI flow §1.1, §5 |
| Depends on | — |
| Status | Ready |

## User Story
As a **developer team**, we want a working Flutter app skeleton with navigation, theming and state management so every later feature has a consistent home.

## Description
Create the Flutter project in `SourceCode/lifeos_app` (Android + iOS) with:
- Riverpod for state, go_router for navigation
- Bottom navigation bar with 5 tabs: Home · Tasks · Vault · Money · More
- Center-docked expandable FAB: ➕ Task · 📸 Scan · 🎤 Voice · 💸 Expense (actions are stubs for now)
- Material 3 theme with light/dark/system, the domain colour tokens (Mind indigo, Money green, Health red, People amber, Work blue, Soul teal, Vault slate), and the 16sp base type scale
- Placeholder screen per tab, each showing the standard illustrated empty state
- Folder structure: `lib/core`, `lib/data`, `lib/features/<feature>`, `lib/shared`
- Lints (`flutter_lints`), formatting, and a CI-ready `flutter test` setup

## Acceptance Criteria
1. `flutter run` launches the app on an Android emulator and opens on the Home tab.
2. Tapping each of the 5 tabs shows that tab's screen. Tab state is kept when switching tabs.
3. Tapping the FAB expands 4 actions. Each action opens a placeholder sheet. Tapping outside collapses the FAB.
4. The theme follows the system light/dark setting. Domain colour tokens are defined in one file (`core/theme/tokens.dart`).
5. Touch targets are ≥ 48dp. All nav items have accessibility labels.
6. `flutter analyze` reports 0 issues, and `flutter test` passes with at least one widget test covering tab navigation.
7. No screen ever shows a blank area: every placeholder uses the shared `EmptyState` widget.

## Out of Scope
Real feature logic, database, notifications, localisation strings (PBI-025).
