# PBI-035 — Profile & Personalization (region/belief-neutral defaults)

| Field | Value |
|---|---|
| Epic | E5 Platform / E6 Engagement |
| Priority | P0 (post-MVP — ships before any new market/beta) |
| Story Points | 5 |
| Spec refs | Features §8 (Soul is opt-in — "respects other faiths, configurable or off"), §10 (dashboard greeting), §13 (onboarding), §14 (settings) |
| Depends on | PBI-021 (Home dashboard), PBI-025 (Settings, EN/UR) |
| Status | In progress (steps 1–4 of 5 done: neutral greeting, greeting style, My Profile, region formats) |

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

## Dev Notes (step 2 — greeting style setting, 2026-11-09)
- **Schema v7:** `user_settings` gains `greet_style` ('auto' default) and `greet_custom` (''), migration tested from every v1–v6 start plus the data-survival case; schema v7 dumped and the generated migration helpers refreshed.
- **Domain:** `GreetStyle` enum lives in `attention.dart`; `greetingText(l, name, now, style, custom)` is the core (explicit `AppLocalizations`, so the digest can render in the saved language ahead of time); `greeting(...)` wraps it with `l10nNow`. Custom with an empty word falls back to auto — the greeting is never blank.
- **Digest:** the morning digest title now comes from the same function at the digest's own fire time (07:30 → morning); `digestTitle` ARB key retired. Style changes resync notifications via the existing `userSettings` table watch — no new plumbing.
- **Settings UI:** a Greeting section (radio: Auto / Salam / Namaste / Hello / Custom… + text field, 24-char cap) with keys `set-greet-*`. Moves to My Profile in step 3.
- **Strings:** `hmGreetSalam/Namaste/Hello/Custom` (± name) + `setGreeting*` labels, EN/UR, generator scripts in `tool/l10n/` kept in sync.
- Tests: style-wins-over-clock unit cases; settings widget flow Salam → custom "Shalom" → back to Auto, asserting the Home app bar each time; digest title in EN, UR and with a chosen style. Found in dev: the custom text field adds a second scrollable (use `ensureVisible`), and the More branch keeps its route state when switching tabs.
- `flutter analyze` clean · full suite 489/489 passed.
- Remaining: steps 3–5 (My Profile screen, region formats/currency sweep, README DoD rule).

## Dev Notes (step 3 — My Profile screen, 2026-11-09)
- **Route** `/more/profile` → `lib/features/profile/profile_screen.dart`. **More** lists My Profile first (avatar + name, or "Your name, greeting and language" while still "Me"); Home's profile button now opens it directly (tooltip "My profile"; `hmProfileMore` retired).
- **No new storage:** name and avatar edit the seeded Me-person through `VaultService.updatePerson` (relation pinned to 'self', still undeletable). A new `selfPersonProvider` exposes it. The placeholder "Me" shows as an empty field with "What should we call you?"; clearing the field never blanks the stored name (last good name kept).
- **Avatar** is the existing emoji avatar (no photo/file handling — stays local, no permissions); `EmojiPicker`/`personEmojis` made public in `vault_sheets.dart` and reused, chips keyed `emoji-<e>`.
- **Live preview** at the top shows exactly what Home will say.
- **Greeting style moved** from Settings to My Profile (keys `set-greet-*` unchanged); **Language mirrored** in both places. Settings' section header extracted to `shared/widgets/section_header.dart` and shared.
- Strings: `mrProfile`, `mrProfileSub`, `profileAboutYou`, `profileNameLabel` in EN/UR + generator script.
- Tests: new `test/features/profile/profile_test.dart` (5): More order + Home entry + placeholder prompt; name → one self record + Home greeting + blank-guard; avatar on Home; greeting style flow (moved from the settings test); Urdu from My Profile.
- `flutter analyze` clean · full suite 493/493 passed.
- Remaining: steps 4–5 (region formats/currency sweep, README DoD rule).

## Dev Notes (step 4 — region formats, 2026-11-09)
- **`lib/core/region.dart`:** `RegionFormats` (symbol, weekStart, weekend, dayFirst) and `AppRegion.current`, kept in step by the app like `AppLocale`. `resolveRegion(deviceLocale, {symbol, weekStart, dateOrder})` = the user's choices over the phone's defaults.
- **Defaults come from the phone's *country*, via small tables** (currency, Sunday/Saturday-first weeks, Fri–Sat weekends, month-first dates). Probed first: `intl` keys its data by *language*, so alone it gives "$" for `en_PK` and "E£" for `ar_SA`/`ar_AE` — wrong for our core markets. `intl` is only the fallback when the locale has no country. Deviation from CLDR, documented in code: Pakistan starts weeks on Monday (Mon–Fri working week; what LifeOS has always shown).
- **Schema v8:** `currency_symbol`, `week_start`, `date_order` (null = follow the phone). **Upgrades keep what users saw** (Rs / Monday / "9 Nov" written by the migration), so an existing user on an en-US phone isn't switched to $ and Sunday weeks; fresh installs follow the phone.
- **Money:** `Money.format` uses the user's symbol (display only — amounts never converted; `currency` columns untouched, multi-currency stays V3); new `Money.formatPlain` and `Money.prefix`. Swept: 9 fragile `.replaceFirst('Rs ', '')` call sites → `formatPlain`; 7 input prefixes → `Money.prefix`; the reminder's per-record `currency: 'PKR'` dropped; ARB keys `atcRsPrefix`/`cpRsPrefix`/`mnRsPrefix` retired.
- **Dates:** `dayMonth()` ("9 Nov" / "Nov 9") in `shared/format.dart`; `formatDay` and 4 hand-built day+month sites (fee schedule, Life Score detail, scan title, OCR fallback title) use it.
- **Week start:** Home's weekly payments, the Overload Shield week, quick-add's "next <day>" rule, and the expiry weekly nudge (now the evening before the user's week starts — Sunday for Monday weeks, unchanged for existing users). **"weekend"/"next weekend"** added to quick-add, resolving to the user's weekend (Sat–Sun, Fri–Sat, Sun-only…); bounded so an empty set can't hang the parser.
- **Applied everywhere text is made:** the app build, `main()` before Auto Tasks/Expiry Guard/score run (generated titles carry amounts), and the reminder isolate. On a region change every live element is marked for one rebuild (state kept) — nothing inherits the region the way widgets inherit the language, so Home/Money in the tab stack would otherwise show stale symbols.
- **My Profile → Region & formats:** currency chips (Auto (phone's symbol), Rs, ₹, $, €, £, AED, SAR, ৳, ¥, ₦, RM) + "Another symbol" field; week starts Auto/Sat/Sun/Mon; dates Auto/"9 Nov"/"Nov 9".
- **Tests:** `test/flutter_test_config.dart` pins the test phone to en-PK and resets the region before every test. New `test/core/region_test.dart` (country defaults incl. the intl traps, overrides and invalid fallbacks, date order, three week starts across Home/Overload/nudge, weekend + "next <day>" parsing, and the AC5 source scan for hard-coded "Rs"); money tests for symbol/prefix/plain/round-trip; migration v1–v7→v8 incl. upgrade preservation and fresh-install nulls; profile widget tests: ₹ + Sunday weeks change Home's week total live, Auto restores; date-order choice.
- Not done (noted for later): a weekend-days override in the UI (weekend follows the phone's country only); existing Auto Task titles keep the symbol they were generated with (new occurrences use the new one); a timezone-based country guess for phones set to en-US abroad.
- `flutter analyze` clean · full suite 516/516 passed, identical on two runs.
- Remaining: step 5 (README DoD rule + AC evidence → Done).

## Grooming Notes
- **Greeting:** `greeting(Person? self)` in `lib/features/home/domain/attention.dart` gains a `GreetingStyle` + `DateTime now` input (keep it pure; the widget injects the clock — same pattern the score/digest code uses). ARB keys: retire `hmSalam`/`hmSalamName`, add `hmMorning(Name)`, `hmAfternoon(Name)`, `hmEvening(Name)`, `hmNight(Name)` + no-name variants, `hmCustom` is pass-through.
- **Storage:** all new settings in the existing settings store (PBI-025 key-value), no schema migration. Avatar file path alongside existing person photo handling.
- **Currency/dates:** central `formatAmount(num)` / `formatDate(DateTime)` helpers in `shared/` that read the settings; replace call-site literals mechanically. Grep inventory first (`Rs`, `DateFormat(`) and list the touched files in the dev notes.
- **Digest title:** `digestTitle` ("Good morning") routes through the same greeting function so the two can't drift.
- **Out of scope:** multi-currency conversion (V3), Arabic/RTL third language (V3), Soul module content (P1), Hijri or other calendars (future opt-in, respecting the same principle).
