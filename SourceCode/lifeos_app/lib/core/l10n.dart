import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// `context.l10n.someKey` — every user-facing string in widgets (PBI-025).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The app's current language, kept in step by `LifeOsApp` whenever the
/// setting changes. Pure helpers that build display text without a
/// `BuildContext` (date words, score labels, notification text) read
/// [l10nNow]. Widgets rebuild on a language switch, so their calls into
/// those helpers pick up the new language at once.
abstract final class AppLocale {
  static Locale current = const Locale('en');
}

AppLocalizations get l10nNow => lookupAppLocalizations(AppLocale.current);
