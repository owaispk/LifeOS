# PBI-035 — Profile & Personalization (region/belief-neutral defaults)

| Field | Value |
|---|---|
| Epic | E5 Platform / E6 Engagement |
| Priority | P0 (post-MVP — ships before any new market/beta) |
| Story Points | 5 |
| Spec refs | Features §8 (Soul is opt-in — "respects other faiths, configurable or off"), §10 (dashboard greeting), §13 (onboarding), §14 (settings) |
| Depends on | PBI-021 (Home dashboard), PBI-025 (Settings, EN/UR) |
| Status | In progress (step 1 of 5 done: neutral greeting) |

## User Story
As a **user anywhere in the world, of any religion**, I want LifeOS to greet me and format my dates, week and money the way *I* choose — with defaults that assume nothing about my culture or faith.

## Design principle (binding for this and future PBIs)
**Religion and culture are never inferred — not from language, not from region.** Neutral defaults work for everyone; anything cultural appears only behind an explicit user choice. (The current bug: "Salam 👋" is the hardcoded English greeting and السلام علیکم the Urdu one — a religious greeting coupled to language.)

## Description

### 1. Neutral, time-based greeting (the fix)
- Replace the static `hmSalam`/`hmSalamName` strings with a time-of-day greeting from the device clock: morning (5:00–11:59) ☀️ / afternoon (12:00–16:59) / evening (17:00–20:59) / night (21:00–4:59, a gentler "Working late?" tone). With the name when the Me-profile has one, without it while it's still "Me".
- Localised in EN and UR like any other string (`subah bakhair…`), with **no religious wording in any default**.

### 2. Greeting style — an explicit choice
- Profile setting **Greeting style**: `Auto — time of day` (default) · `Salam` · `Namaste` · `Hello` · `Custom…` (free text, e.g. Shalom, Sat Sri Akal, Ciao; sensible length cap; emoji allowed).
- The chosen style applies on Home and in the morning-digest title (PBI-023's "Good morning" string follows the same setting).
- If the Soul module is ever enabled with a faith selected (P1), it may **offer** switching the greeting ("Use 'Salam'?") — one dismissible prompt, never an automatic change.

### 3. My Profile screen
- **More → My Profile** (top of the More tab, replacing the scattered entry points):
  - **Name** — "What should we call you?" — edits the existing protected Me-person (same record Vault/Tasks use; no new storage).
  - **Photo/avatar** — optional, stored locally like person photos; shown on Home's profile button.
  - **Language** — moves/mirrors the existing EN/UR setting (PBI-025).
  - **Greeting style** — as above.
  - **Region & formats** — date format (system / DD-MM-YYYY / MM-DD-YYYY), **first day of week** (system default; Mon/Sat/Sun — Saturday matters for Gulf users), defaulted from the device locale, each overridable.
  - **Currency symbol** — display-only setting (default from device locale, e.g. Rs, ₹, $, €, ر.س, £). Replaces every hardcoded "Rs" in Money, ATC amounts, forecast and parser chips. Full multi-currency (conversion, per-account) stays V3; this is formatting only.
- Onboarding (PBI-022) keeps its name step and gains nothing mandatory — locale defaults do the rest silently.

### 4. Ripple points (where the settings must actually apply)
- **First day of week:** task Upcoming grouping, forecast month view, any calendar grids.
- **"Weekend" in the NL parser** (PBI-010): resolves per the user's week setting, not hardcoded Sat/Sun.
- **Currency symbol:** money screens, ATC proposal sheets, widget payment line (PBI-033 when built), export CSV headers unchanged (raw numbers).
- **Date format:** display-level only; storage stays ISO.

### 5. Definition of Done addition (process change)
Add to the backlog README's DoD: *"No culturally specific words, symbols, calendars or assumptions in default UI strings; cultural content only behind an explicit user choice."* Quick audit in this PBI: default greeting (fixed here), hardcoded "Rs" (fixed here), the 🕌 emoji if used in any default surface (Soul's own opt-in screens are fine), Friday/Sunday assumptions.

## Acceptance Criteria
1. Fresh install, no choices made: the Home greeting is time-of-day based and contains no religious wording in EN and UR; at 09:00/14:00/19:00/23:00 the four variants appear (clock-injected widget tests).
2. Setting Greeting style to Salam / Namaste / Hello / Custom "Shalom" changes the Home greeting and the morning-digest title immediately and persists across restart; Auto restores time-based.
3. My Profile edits the same Me-person record used by Vault and Tasks (renaming in either place updates both; the Me-person remains undeletable). Avatar appears on the Home profile button.
4. First-day-of-week Sat/Sun/Mon changes Upcoming's week grouping and the forecast month grid accordingly; "weekend" in quick-add resolves to the chosen week-end days (parser tests cover all three settings).
5. Changing the currency symbol updates every money amount on Money, ATC sheets, task payment chips and the forecast; no "Rs" remains hardcoded in any UI string (source scan + widget checks). Stored values and CSV exports are unchanged raw numbers.
6. Device-locale defaults: a device set to en-US yields Sun/MM-DD/$; ur-PK yields Mon/DD-MM/Rs — each overridable, override wins over locale after restart.
7. All new strings localised EN/UR; everything works fully offline; `flutter analyze` clean and the existing suite passes (greeting-dependent tests updated, not deleted).
8. README DoD gains the neutrality rule (AC is the diff itself).

## Dev Notes (step 1 — neutral greeting, 2026-11-09)
- `greeting(Person?)` → pure `greeting(Person? self, DateTime now)` in `lib/features/home/domain/attention.dart`; Home already watches `nowProvider`, so the clock is injected and testable.
- ARB keys `hmSalam`/`hmSalamName` retired; added `hmGreetMorning/Afternoon/Evening/Night` (± `Name`) in EN and UR — time-based, no religious wording in either language. The string-generator helper `tool/l10n/strings_money_home.py` updated too so a regeneration can't reintroduce the old strings.
- Tests: the greeting unit test now covers all four periods, the name/no-name/"Me" rules and every boundary hour (5:00, 12:00, 17:00, 21:00, 4:59 — AC1); `app_shell_test` follows the fixed 10:00 test clock ("Good morning ☀️").
- `flutter analyze` clean · full suite 486/486 passed.
- Remaining: steps 2–5 (greeting-style setting + digest title routing, My Profile screen, region formats/currency sweep, README DoD rule).

## Grooming Notes
- **Greeting:** `greeting(Person? self)` in `lib/features/home/domain/attention.dart` gains a `GreetingStyle` + `DateTime now` input (keep it pure; the widget injects the clock — same pattern the score/digest code uses). ARB keys: retire `hmSalam`/`hmSalamName`, add `hmMorning(Name)`, `hmAfternoon(Name)`, `hmEvening(Name)`, `hmNight(Name)` + no-name variants, `hmCustom` is pass-through.
- **Storage:** all new settings in the existing settings store (PBI-025 key-value), no schema migration. Avatar file path alongside existing person photo handling.
- **Currency/dates:** central `formatAmount(num)` / `formatDate(DateTime)` helpers in `shared/` that read the settings; replace call-site literals mechanically. Grep inventory first (`Rs`, `DateFormat(`) and list the touched files in the dev notes.
- **Digest title:** `digestTitle` ("Good morning") routes through the same greeting function so the two can't drift.
- **Out of scope:** multi-currency conversion (V3), Arabic/RTL third language (V3), Soul module content (P1), Hijri or other calendars (future opt-in, respecting the same principle).
