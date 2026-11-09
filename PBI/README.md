# LifeOS — Product Backlog (MVP / P0)

**Source of truth:** `LifeOS-Founders-Pack/` (features spec, UI flow, data model).
**Working rule:** nothing is developed unless it first exists here as a PBI with a Description, Acceptance Criteria and Story Points. Code commits reference their PBI id (e.g. `PBI-001: …`).

**Story points:** Fibonacci (1, 2, 3, 5, 8, 13). 1 pt ≈ half a dev-day of focused work, including tests.
**Definition of Ready:** user story, description, testable AC, story points, dependencies listed.
**Definition of Done:** every AC demonstrably met · `flutter analyze` clean · unit/widget tests for the logic pass · works offline · PBI status updated here.

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
| 30 | [PBI-030 Diagnostics Log & Share](PBI-030-diagnostics-log.md) | E5 Platform | 3 | 025, 007 | Done |
| 31 | [PBI-031 Flagship: Compact, Professional Layout](PBI-031-flagship-compact-layout.md) | E5 Platform / Design | 5 | 001, 025 | Done |

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
- PBI-026 Supabase backend + offline sync (push/pull, conflict rules) + E2E encrypted cloud backup (premium)
- PBI-027 Premium cloud LLM classification fallback
- PBI-028 Share-safe expiring links, watermark, bundles
- PBI-029 Premium/subscription & free-tier limits (25 docs / 3 rules)
- V2 (P1): Health, People, Work/Study, Soul, Goals, full Money, Emergency Card, appointments OCR
- V3 (P2): Family sharing, AI weekly plan, HealthKit/steps, multi-currency, Arabic
