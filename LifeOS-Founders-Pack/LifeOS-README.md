# LifeOS — Founder's Pack

**Date:** 2026-11-08 · Concept, specification, design & prototype package

## Contents

| File | What it is |
|---|---|
| `lifeos-features-spec.md` | Deep feature specification — 7 life domains, Document Vault, Auto Task Creator (ATC), Life Score, free/premium split, MVP build order |
| `lifeos-ui-flow.md` | UI/screen flow document — navigation map, every screen with wireframes, modals, notification actions, design system notes |
| `lifeos-data-model.md` | Database schema (Postgres/Supabase + Drift), offline-first sync protocol, zero-knowledge encryption model, API design, scale notes |
| `lifeos-prototype.html` | Clickable visual prototype — open in any browser. Three look templates: 🖤 Flagship Pro (dense, OLED glass), 🔥 Funky, 📖 Classic (large text for elders) |

## How to view the prototype

Just double-click `lifeos-prototype.html` — it opens in any modern browser (Chrome/Edge recommended for the glass effects).

**Try these flows:**
1. Tap the Life Score ring → breakdown
2. ➕ → 📸 Scan → full scan flow with live OCR field extraction
3. Tasks → check off ⚡ School fee → the payment completion chain
4. Vault → 247-document dataset, filters, people profiles
5. More → in-app Look Template picker
6. Wait ~9 seconds on Home → an ATC pattern proposal appears

## Recommended tech stack (summary)

- **App:** Flutter (one codebase: Android + iOS), Riverpod, Drift (offline-first SQLite)
- **Backend:** Supabase (Postgres, Auth, RLS, Edge Functions) → scale with Cloudflare R2 for encrypted document storage
- **OCR:** on-device Google ML Kit first; cloud LLM extraction as a premium fallback
- **Security:** AES-256-GCM encrypted on device before upload — zero-knowledge vault

## MVP build order (~3 months, 2 Flutter devs)

1. Scan → OCR → Vault (folders, people, search)
2. Expiry Guard
3. Tasks + Today view + voice add
4. ATC: monthly payments engine + bill pattern learning
5. Money light: auto expense log + forecast
6. Life Score v1
7. Dashboard, onboarding, notification diet, app lock
