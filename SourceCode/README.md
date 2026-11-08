# LifeOS — Source Code

| App | Path | Stack |
|---|---|---|
| Mobile app (Android + iOS) | `lifeos_app/` | Flutter · Riverpod · go_router · Drift (SQLite, offline-first) |

## Rules
- Nothing is built unless a PBI exists for it in `../PBI/` (description, acceptance criteria, story points).
- Commit messages start with the PBI id: `PBI-001: …`.
- Before a PBI is marked Done: `flutter analyze` is clean and `flutter test` passes.

## Run
```bash
cd SourceCode/lifeos_app
flutter pub get
dart run build_runner build   # after changing Drift tables (data/db/*.dart)
flutter test
flutter run            # Android emulator / device
flutter run -d chrome  # quick preview in a browser
```

## Layout (`lifeos_app/lib`)
```
core/      theme, router, ids (UUIDv7), money (minor units)
data/      Drift schema (db/), repositories (outbox + soft delete), seed
features/  one folder per feature: home, tasks, vault, money, more,
           capture (scan/import/share-in), reminders (local notifications)
shared/    reusable widgets (app shell, empty state, quick actions)
```

## Data rules
- Always write through `Repositories` (never `db.into(...)` directly): it sets ids, versions, timestamps and queues the sync outbox.
- Money is `amount_minor` integers; use `Money.parseMinor` / `Money.format`.
- Generated `*.g.dart` files are committed so the project builds without running codegen.
- Schema changes: bump `schemaVersion`, add an `onUpgrade` step, then snapshot and regenerate the migration test helpers:
  `dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/` and
  `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`.
- Device features (scanner, file picker, share-in, storage, notifications) sit behind interfaces; tests use the fakes in `test/fakes.dart`.
