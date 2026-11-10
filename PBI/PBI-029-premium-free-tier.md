# PBI-029 — Premium Subscription & Free-Tier Limits

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 (post-MVP) |
| Story Points | 8 |
| Spec refs | Features §15 (free vs premium split); §2.5 (ATC rule limit); §1.1 (Vault) |
| Depends on | PBI-002 (settings store), PBI-013 (the 3-rule stub), PBI-003 (capture, where the document limit bites) |
| Status | Done — store configuration and device QA pending |

## User Story
As a **user**, I want to pay for Premium from inside the app and have the limits lift immediately, so I can keep scanning past 25 documents and adding auto-rules past 3 — and as a **free user**, I want to know where the limit is before I hit it, not after.

## Description

This is the PBI the premium work waits on. It lands three things and nothing else: a **real entitlement** (replacing `premiumProvider`, which has returned a hard-coded `false` since PBI-013), the **two free-tier limits the spec names**, and the **screen that sells and restores the subscription**.

### Entitlement
- Store billing through `in_app_purchase` (Google Play Billing; StoreKit on iOS — see Out of Scope on the possible split). One auto-renewing subscription product, monthly, with the regional price the spec names (~$2/mo, Rs 400–500).
- **No account system.** Entitlement is the store's purchase record for the signed-in store account, exactly as PBI-027b assumes ("a Play Billing purchase-token check is sufficient; a full account system is explicitly not required"). LifeOS has no users table, no login, no server.
- The last known entitlement and its expiry are cached in the settings row, so the app knows what the user has paid for **before** the store responds, and while offline.
- `premiumProvider` becomes the single read point for the whole app. Nothing else may decide what is premium — PBI-027a/b, and any later PBI, read this one provider.

### Offline and failure behaviour
The app is offline-first (PBI-003 AC4, PBI-032 AC7); billing must not break that.
- A cached active entitlement keeps Premium working offline indefinitely — a user on a plane does not lose features they paid for.
- The store is re-checked on resume, at most once an hour.
- A store that cannot be reached, or a query that fails, **keeps the cached answer** and logs one line (PBI-030). It never downgrades the user and never shows an error screen.
- Entitlement only drops to free when the store itself says the subscription has lapsed.

### The two limits
| Limit | Free | Premium | Where it bites |
|---|---|---|---|
| Documents in Vault | 25 | Unlimited | Before saving a capture (PBI-003) |
| ATC auto-rules | 3 active | Unlimited | Already enforced in `AtcService` (PBI-013) |

- The ATC limit exists and works; this PBI only replaces the `isPremium: false` it is fed.
- The document limit is new. It counts **live** documents — archived ones count, trashed ones do not — and is checked at save, not at scan, so the user never loses a capture they have already taken.
- **An existing library is never held hostage.** A user already over a limit when this ships keeps every document and every rule, readable and editable. The limit blocks *adding*, never *using* or *seeing*. Nothing is deleted, hidden or disabled, ever.
- **Warn before the wall:** at 20 of 25 documents the Vault shows one quiet inline line ("5 documents left on the free plan"). At the limit, saving shows the upgrade sheet and the capture is kept in the review session so **Not now** does not throw the scan away.

### The Premium screen
Settings → Premium is a disabled "Coming soon" row today (`settingsPremiumSub`). It becomes a real screen:
- What Premium includes **today**, honestly — unlimited documents and unlimited auto-rules. Features the spec's §15 table lists but that do not exist yet (cloud backup, share links, AI weekly plan, family sharing, multi-device sync) are **not advertised**, because selling them now would be selling something we cannot deliver.
- Price from the store, in the store's own currency and formatting — never a hard-coded "$2".
- **Subscribe**, **Restore purchases**, and a link to manage or cancel in the store. Restore is its own button, not buried: a user reinstalling on a new phone must be one tap from what they already pay for.
- Current state is always visible: Free, Premium, or Premium ending on a date after they cancel.
- The upgrade sheet ATC already shows (`atcUpgradeTitle` / `atcUpgradeBody` / `atcSeePremium`, PBI-013) routes here instead of nowhere.

### Privacy
- No analytics, no attribution SDK, no purchase data leaving the device beyond the store SDK's own traffic. Purchase tokens are logged nowhere (PBI-030 scrubber rules apply).

## Acceptance Criteria
1. A free user with 25 live documents who saves a 26th is shown the upgrade sheet and the document is **not** saved; **Not now** returns them to the review step with the capture intact, and the Vault still holds exactly 25.
2. A premium user saves a 26th, a 100th and a 1000th document with no prompt and no limit; the same user adds a 4th, 5th and 6th active ATC rule with no prompt (PBI-013 AC6 lifts).
3. Entitlement comes from one provider: with the store reporting an active subscription, `premiumProvider` is true across Vault, ATC and Settings in the same session, with no restart.
4. A user who was over a limit before this shipped (30 documents, 5 rules) loses nothing: every document opens, every rule still runs, nothing is deleted or hidden. Only *adding* is blocked until they upgrade.
5. Offline with a cached active entitlement, Premium keeps working and no error is shown. A store query that fails keeps the previous answer (one log line, PBI-030) and never downgrades the user.
6. Restore purchases on a fresh install, signed in to the store account that owns the subscription, returns Premium without a second payment.
7. The Premium screen shows the store's own localised price, and lists only features that exist today — a test asserts the copy names no unbuilt feature.
8. At 20 of 25 documents the Vault shows the remaining count once, inline; it is never a notification (PBI-023 holds).
9. Cancelling in the store leaves the user premium until the paid period ends, then drops to free at the next check — it does not revoke the moment they cancel.
10. Nothing reaches the billing SDK until the Premium screen is opened or a limit is hit: a cold start of a free user who opens neither makes no store call (counted by the fake, as in PBI-032 AC5).

## Out of Scope
- **Ads** ("minimal, outside dashboard" in §15). A separate decision with its own privacy weight — not bundled into the paywall.
- **Gating OCR field extraction.** §15 lists free as "Basic (title only)", but the MVP shipped full extraction to everyone. Taking it back from existing users is a product decision, not a limit this PBI enforces — raise it separately if it is still wanted.
- Cloud backup (PBI-026), share links (PBI-028), AI weekly plan and family sharing (V2/V3). They are gated by `premiumProvider` **when they are built**; this PBI only supplies the flag.
- Premium AI (PBI-027a/027b) — unblocked by this PBI, built in those.
- Promo codes, trials, win-back offers, annual plans, family plans.
- Receipt validation on a server. There is no server, by design.

## Grooming Notes
- `premiumProvider` lives in `features/atc/atc_providers.dart:10` today, which is the wrong home once it is real — move it to a `features/premium/` of its own and leave an export where ATC expects it.
- Wrap the plugin behind a `BillingSource` interface with a fake, the pattern `ShareInbox` (PBI-003) and `CalendarSource` (PBI-032) already follow. The fake must count calls so AC10 cannot pass by accident.
- Entitlement cache: two columns on `user_settings` (`premium_until` as epoch ms, nullable; `premium_checked_at`). That is schema v11 — see the v10 migration in `app_database.dart` for the shape, and remember `drift_dev schema dump` + `generate` and the `migration_test.dart` pairs.
- The document count wants a cheap `COUNT(*)` on live documents, not loading every row — Vault already holds thousands in principle.
- `freeTierRuleLimit = 3` is in `features/atc/domain/atc_schedule.dart`; put the document limit beside it, not in the UI.
- Store configuration (a Play Console subscription product, licence testers) is the part that cannot be done from the repo and will gate device QA — treat it as a prerequisite, not a task.
- Price formatting comes from `ProductDetails.price`, which is already localised; do not route it through `Money` (PBI-035 region formats are for the user's own money, not the store's).
- Worth deciding at planning: whether iOS ships here or splits, as PBI-034 split its share extension. The Dart flow is one plugin for both stores, so the split would be about App Store Connect setup and a Mac to test on, not about code.

## Dev & QA Notes (2026-11-10)

New dependency: `in_app_purchase` (one plugin, both stores).

Code, under `lib/features/premium/`:
- `platform/billing_source.dart`: `BillingSource` with `StoreBilling` and an inert `NoBilling`, the default until `main()` swaps the real one in. The plugin's `purchaseStream` is subscribed from launch, as it requires, and every purchase it hands back is completed.
- `domain/limits.dart` (pure Dart): `freeTierDocumentLimit = 25` beside the existing `freeTierRuleLimit = 3`, plus the entitlement-cache rules.
- `premium_providers.dart`: `premiumProvider` — now the single read point — and `PremiumService` (subscribe, restore, refresh).
- `ui/premium_screen.dart`, `ui/upgrade_prompt.dart` (shared by ATC and capture), `ui/premium_refresher.dart`.

`premiumProvider` moved out of `features/atc/atc_providers.dart`, which re-exports it so ATC's callers are untouched. Schema v11 adds `premium_until` and `premium_checked_at`.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Widget: with 25 documents, saving a 26th shows the upgrade prompt, the Vault still holds 25, and **Not now** leaves the review step up with the scan intact. |
| 2 | ✅ | Widget: a premium user with 25 documents saves the 26th with no prompt. Unit: the limit passes at 25, 10 000 and anything else once premium. The ATC rule limit lifts through the same flag. |
| 3 | ✅ | Widget: one setting change makes the Vault drop its warning and Settings say "You're on Premium." in the same session, no restart. |
| 4 | ✅ | Widget: a free user with 30 documents keeps all 30, still free. Unit: adding is blocked and no warning line is shown — someone already over the limit is not nagged about it. |
| 5 | ✅ | Widget: a store that answers "could not ask" leaves `premium_until` exactly as it was. `refresh()` returns early on a null answer and logs one line; only a real reply ever writes. |
| 6 | ✅ | Widget: Restore on an account that owns the subscription turns Premium on with `purchases == 0` — restoring is not buying. |
| 7 | ✅ | Widget: the screen shows the store's own formatted price. A loop asserts the rendered screen contains none of backup / sync / AI / family / link, so an unbuilt feature cannot quietly reappear in the copy. |
| 8 | ✅ | Widget: at 20 of 25 the Vault shows the line; at 5 of 25 it does not; a premium user never sees it. It is a `ListTile` in the Vault, never a notification. |
| 9 | ⚠️ Partly | The behaviour rests on the store reporting ownership until the paid period ends, and on `PremiumRefresher` re-checking on resume. Testable only against a real store — see below. |
| 10 | ✅ | Widget: a free user who opens the Vault and Home makes **0** store calls. The fake counts every method. |

`flutter analyze`: no issues · full suite `flutter test`: **612/612 passed** (17 new).

**Two honest deviations from the Description above:**

1. **The screen cannot show "Premium ending on <date>".** `in_app_purchase` gives no expiry date client-side; a real one needs server-side receipt validation, which this PBI rules out ("There is no server, by design"). The screen instead says Premium is managed in the store and that cancelling keeps it until the paid period ends. Revisit if PBI-026 ever brings a backend.

2. **`premium_until` is a trust horizon, not the subscription's real end date.** A confirmed purchase is trusted for 60 days without the store being reachable. This is what makes AC5 work: a paying user keeps what they paid for on a plane, and only a store that actually answers can take Premium away. The cost is that someone who cancels and then stays offline keeps Premium for up to 60 days — the right way round for a paid feature.

**How AC9 and AC10 coexist:** `PremiumRefresher` re-checks on resume, but only when `premium_until` is non-null. A user who has never subscribed is never checked, so nothing reaches the billing SDK unless they open the Premium screen or hit a limit.

**Not verified:** no device pass, and it cannot happen until the store side exists — a subscription product `lifeos_premium_monthly` in Play Console (and App Store Connect) plus licence testers. Until then the real purchase flow, restore on a fresh install, and AC9's lapse behaviour are all untested against anything but a fake. That configuration is a prerequisite, not a task in this PBI.
