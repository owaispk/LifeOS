# LifeOS — Source Code

| App | Path | Stack |
|---|---|---|
| Mobile app (Android + iOS) | `lifeos_app/` | Flutter · Riverpod · go_router (Drift arrives with PBI-002) |

## Rules
- Nothing is built unless a PBI exists for it in `../PBI/` (description, acceptance criteria, story points).
- Commit messages start with the PBI id: `PBI-001: …`.
- Before a PBI is marked Done: `flutter analyze` is clean and `flutter test` passes.

## Run
```bash
cd SourceCode/lifeos_app
flutter pub get
flutter test
flutter run            # Android emulator / device
flutter run -d chrome  # quick preview in a browser
```

## Layout (`lifeos_app/lib`)
```
core/      theme (tokens, Material 3 themes), router
features/  one folder per feature: home, tasks, vault, money, more
shared/    reusable widgets (app shell, empty state, quick actions)
```
