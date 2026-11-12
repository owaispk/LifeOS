# LifeOS — Product Backlog (MVP / P0)

**Source of truth:** `LifeOS-Founders-Pack/` (features spec, UI flow, data model).
**Working rule:** nothing is developed unless it first exists here as a PBI with a Description, Acceptance Criteria and Story Points. Code commits reference their PBI id (e.g. `PBI-001: …`).

**Story points:** Fibonacci (1, 2, 3, 5, 8, 13). 1 pt ≈ half a dev-day of focused work, including tests.
**Definition of Ready:** user story, description, testable AC, story points, dependencies listed.
**Definition of Done:** every AC demonstrably met · `flutter analyze` clean · unit/widget tests for the logic pass · works offline · **neutral by default** · PBI status updated here.

**Neutral by default (since PBI-035):** no religious or culture-specific words, symbols, calendars or assumptions in default UI strings or behaviour, in any language. Cultural content (a "Salam" greeting, a currency symbol, a Saturday week) appears only behind an explicit user choice or the phone's own region setting — never inferred from the app language. Enforced by `test/l10n_neutrality_test.dart` (strings) and the hard-coded-currency scan in `test/core/region_test.dart`.

## Backlog (MVP build order, per spec §16)

| # | PBI | Epic | SP | Depends on | Status |
|---|---|---|---|---|---|
| 1 | [PBI-001 Project Foundation & App Shell](PBI-001-project-foundation.md) | E0 Foundation | 5 | — | Done |
| 2 | [PBI-002 Offline-First Local Database](PBI-002-local-database.md) | E0 Foundation | 8 | 001 | Done |
| 3 | [PBI-003 Document Capture](PBI-003-document-capture.md) | E1 Vault | 8 | 002 | Done |
| 4 | [PBI-004 OCR, Classification & Extraction](PBI-004-ocr-classification.md) | E1 Vault | 13 | 003 | Done |
| 5 | [PBI-005 Vault Folders, People, Tags](PBI-005-vault-organization.md) | E1 Vault | 5 | 002 | Done |
| 6 | [PBI-006 Vault Full-Text Search](PBI-006-vault-search.md) | E1 Vault | 5 | 002, 004 | Done |
| 7 | [PBI-007 Document Viewer & Trash](PBI-007-document-viewer.md) | E1 Vault | 5 | 005 | Done |
| 8 | [PBI-008 Expiry Guard](PBI-008-expiry-guard.md) | E1 Vault | 5 | 002, 012 | Done |
| 9 | [PBI-009 Tasks: Today & Upcoming](PBI-009-tasks-today-upcoming.md) | E2 Mind | 8 | 002 | Done |
| 10 | [PBI-010 Natural-Language & Voice Add](PBI-010-natural-language-voice-add.md) | E2 Mind | 8 | 009 | Done |
| 11 | [PBI-011 Overload Shield](PBI-011-overload-shield.md) | E2 Mind | 5 | 009 | Done |
| 12 | [PBI-012 Local Reminders & Actionable Notifications](PBI-012-local-notifications.md) | E5 Platform | 8 | 009 | Done |
| 13 | [PBI-013 ATC Monthly Payments Engine](PBI-013-atc-payments-engine.md) | E3 ATC | 8 | 009, 012 | Done |
| 14 | [PBI-014 ATC Bill Pattern Learning](PBI-014-atc-bill-pattern-learning.md) | E3 ATC | 8 | 004, 013 | Done |
| 15 | [PBI-015 ATC Fees & Tuition](PBI-015-atc-fees-tuition.md) | E3 ATC | 5 | 013, 004 | Done |
| 16 | [PBI-016 Payment Completion Chain](PBI-016-payment-completion-chain.md) | E3 ATC | 5 | 013, 018, 003 | Done |
| 17 | [PBI-017 ATC Rules Manager](PBI-017-atc-rules-manager.md) | E3 ATC | 3 | 013 | Done |
| 18 | [PBI-018 Money Expense Log](PBI-018-money-expense-log.md) | E4 Money | 5 | 002 | Done |
| 19 | [PBI-019 Monthly Forecast](PBI-019-monthly-forecast.md) | E4 Money | 5 | 013 | Done |
| 20 | [PBI-020 Life Score v1](PBI-020-life-score.md) | E6 Engagement | 8 | 009, 013, 008 | Done |
| 21 | [PBI-021 Home Dashboard](PBI-021-home-dashboard.md) | E6 Engagement | 5 | 020, 009, 008, 019 | Done |
| 22 | [PBI-022 Onboarding](PBI-022-onboarding.md) | E6 Engagement | 5 | 003, 013, 019 | Done |
| 23 | [PBI-023 Notification Diet](PBI-023-notification-diet.md) | E5 Platform | 5 | 012, 020 | Done |
| 24 | [PBI-024 App Lock & Encryption](PBI-024-app-lock-encryption.md) | E5 Security | 8 | 003 | Done |
| 25 | [PBI-025 Settings, Export, EN/UR](PBI-025-settings-export-language.md) | E5 Platform | 5 | 001, 024 | Done |
| | **MVP total** | | **158** | | |

## Post-MVP backlog (groomed)

| # | PBI | Epic | SP | Depends on | Status |
|---|---|---|---|---|---|
| 26a | [PBI-026a Optional Account & Recovery Phrase](PBI-026a-account-recovery.md) | E5 Platform / Cloud | 8 | 024, 029, 025 | Ready |
| 26b | [PBI-026b End-to-End Encrypted Backup & Restore](PBI-026b-encrypted-backup-restore.md) | E5 Platform / Cloud | 13 | 026a, 024, 029 | Ready (blocked by 026a) |
| 26c | [PBI-026c Multi-Device Sync](PBI-026c-multi-device-sync.md) | E5 Platform / Cloud | 13 | 026a, 026b | Ready (blocked by 026b) |
| 27a | [PBI-027a Premium AI: Bring-Your-Own-Key (no backend)](PBI-027a-premium-ai-byok.md) | E3 ATC / E1 Vault | 5 | 004, 024, 029 | Done |
| 27b | [PBI-027b Premium AI: Managed Mode + Lightweight Proxy](PBI-027b-premium-ai-managed.md) | E3 ATC / E1 Vault | 5 | 027a, 029 | Done (client); proxy undeployed |
| 28a | [PBI-028a Share Watermark & Document Bundles](PBI-028a-share-watermark-bundles.md) | E1 Vault | 5 | 007, 024, 025 | Done (device QA 2026-11-11) |
| 28b | [PBI-028b Share-Safe Expiring Links (Premium)](PBI-028b-expiring-share-links.md) | E1 Vault / Cloud | 8 | 026a, 026b, 028a, 029 | Ready (blocked by 026b) |
| 29 | [PBI-029 Premium Subscription & Free-Tier Limits](PBI-029-premium-free-tier.md) | E5 Platform | 8 | 002, 013, 003 | Done (store setup pending) |
| 30 | [PBI-030 Diagnostics Log & Share](PBI-030-diagnostics-log.md) | E5 Platform | 3 | 025, 007 | Done |
| 31 | [PBI-031 Flagship: Compact, Professional Layout](PBI-031-flagship-compact-layout.md) | E5 Platform / Design | 5 | 001, 025 | Done |
| 32 | [PBI-032 Device Calendar in Today View (read-only)](PBI-032-device-calendar-today.md) | E2 Mind | 5 | 009, 021 | Done |
| 33 | [PBI-033 Home-Screen Widget](PBI-033-home-screen-widget.md) | E6 Engagement | 8 | 009, 013, 020, 021 | Dev complete (Android) — device QA pending; iOS split to follow-up |
| 34 | [PBI-034 Share Text to Task](PBI-034-share-text-to-task.md) | E3 ATC / E2 Mind | 3 | 010, 003 | Done (Android) |
| 35 | [PBI-035 Profile & Personalization (neutral defaults)](PBI-035-profile-personalization.md) | E5 Platform / E6 Engagement | 5 | 021, 025 | Done |
| 36 | [PBI-036 iOS Share Extension](PBI-036-ios-share-extension.md) | E5 Platform | 5 | 003, 034 | In progress — config files written; Xcode target + device QA need a Mac |
| 37 | [PBI-037 iOS Home-Screen Widget (WidgetKit)](PBI-037-ios-home-screen-widget.md) | E6 Engagement | 8 | 033 | Ready (blocked: needs a Mac) |
| 38 | [PBI-038 Testing Feedback (Nov 2026 test pass)](PBI-038-testing-feedback.md) | Cross-cutting | TBD | per item | Open — collecting feedback (not Ready) |
| 39 | [PBI-039 Personal AI: Ask, Plan and Insights](PBI-039-personal-ai.md) | E7 Personal AI | 39 (7 slices, max 8) | 027a, 027b, 029 + per slice | Ready — 039a first |

## Suggested sprint plan (2 devs, 2-week sprints, ~27 SP/sprint → 6 sprints ≈ 3 months)

| Sprint | PBIs | SP |
|---|---|---|
| S1 | 001, 002, 009, 018 | 26 |
| S2 | 003, 005, 012, 011 | 26 |
| S3 | 004, 006, 007 | 23 |
| S4 | 008, 013, 016, 017, 019 | 26 |
| S5 | 014, 015, 020, 021 | 26 |
| S6 | 010, 022, 023, 024, 025 | 31 |

## Sprint status
| Sprint | Done | Dev complete, device QA pending | In review |
|---|---|---|---|
| S1 | 001, 002, 009, 018 | — | — |
| S2 | 003, 005, 011, 012 | — | — |
| S3 | 004, 006, 007 | — | — |
| S4 | 008, 013, 016, 017, 019 | — | — |
| S5 | 014, 015, 020, 021 | — | — |
| S6 | 010, 022, 023, 024, 025 | — | — |

**All 6 MVP sprints are closed (25/25 PBIs, 158 SP).** Device QA ran on 2026-11-09 on an Android 17 emulator: launch, camera scan, on-device OCR, PDF view, OS share sheet, an offline reminder and a reminder after reboot. Two bugs found and fixed: neutral share file names (PBI-007) and multi-group reference numbers (PBI-004). Remaining for a physical phone: OCR accuracy on photos of real paper documents.

## Not yet groomed (post-MVP, will become PBIs before development)
- V2 (P1): Health, People, Work/Study, Soul, Goals, full Money, Emergency Card, appointments OCR
- V3 (P2): Family sharing, HealthKit/steps, multi-currency, Arabic
