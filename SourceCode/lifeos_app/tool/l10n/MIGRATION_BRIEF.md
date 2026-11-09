# Moving hard-coded UI strings to English/Urdu (PBI-025 AC2)

Flutter app at `SourceCode/lifeos_app` (Flutter 3.47, Riverpod 3, gen-l10n).
Flutter: `C:/Users/owais.aized/dev/flutter/bin/flutter`. Set `PYTHONUTF8=1`
for Python.

## How localisation works here
- Strings live as `(English, Urdu)` pairs in `tool/l10n/strings_*.py`
  (a dict `S = {key: (en, ur)}`). `python tool/l10n/build_arb.py` merges every
  `strings_*.py` into `lib/l10n/app_en.arb` + `app_ur.arb` (and fails on a
  duplicate key); then `flutter gen-l10n` generates `AppLocalizations`.
- In widgets: `import '<relative>/core/l10n.dart';` then `context.l10n.key`.
- Where there is no `BuildContext` (pure helpers that build display text):
  `l10nNow.key` (same import). It follows the app's current language.
- Placeholders: `"Due {date}"` → a method taking **String** arguments:
  `l.dueOn(formatDay(d))`. Plurals: `"{n, plural, =1{1 task} other{{n} tasks}}"`
  → takes an **int**. Pass numbers to String placeholders as `'$n'`.
- Existing shared keys you may reuse (don't redefine): see
  `tool/l10n/strings_core.py` (today/tomorrow/yesterday, weekday/month names)
  and `tool/l10n/strings_s6.py` (e.g. `cancel`, `create`, `skip`, `next`,
  `amount`, `name`, `trash`, `continueLabel`).

## Your job
1. Only edit the files in **your** list, plus your own new file
   `tool/l10n/strings_<group>.py`. Every key you add must start with your
   **prefix** (avoids collisions with the other three people doing this in
   parallel).
2. Replace every user-facing string literal in your files with an l10n key.
   This includes the ones `python tool/l10n/scan.py -v` lists (Text(...),
   label:, title:, tooltip:, hintText:, message:, subtitle:, SnackBar
   contents…), **and** obvious display-text helpers in your files that
   return words (switch expressions of labels, `'Due $x'` builders).
   Not: keys/ids (`ValueKey('...')`), route paths, DB values, enum names,
   log text, asset names, data written to the database.
3. **The English text must stay exactly the same** (tests find widgets by
   English text). Only move it.
4. Write a natural, polite Urdu translation (Pakistani usage, as on a phone
   app). Keep emoji, "LifeOS", "Rs", "⚡", digits and units like "%" as they
   are. Keep it short enough for buttons.
5. Remove `const` where a widget now reads `context.l10n` (the analyzer will
   tell you).
6. Then run, from `SourceCode/lifeos_app`:
   - `PYTHONUTF8=1 python tool/l10n/build_arb.py && flutter gen-l10n`
     (others run this too; if it fails on someone else's half-written file,
     just run it again),
   - `flutter analyze <your files>` → fix every issue in your files,
   - `PYTHONUTF8=1 python tool/l10n/scan.py -v` → none of your files listed.
7. **Do not run `flutter test`** (parallel runs lock the SQLite DLL). Don't
   format or touch other files. Don't commit.

Report back: files changed, number of keys added, anything you left in
English on purpose and why.
