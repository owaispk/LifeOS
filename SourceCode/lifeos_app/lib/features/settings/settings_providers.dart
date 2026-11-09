import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/region.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repositories.dart';
import '../home/domain/attention.dart' show GreetStyle;

/// The single settings row, live; null until loaded (and on the web
/// preview, which has no local database).
final settingsProvider = StreamProvider<UserSettingsRow?>(
  (ref) => ref
      .watch(repositoriesProvider)
      .userSettings
      .watchAll()
      .map((rows) => rows.firstOrNull),
);

final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(repositoriesProvider)),
);

/// Writes to the settings row (PBI-025).
class SettingsService {
  SettingsService(this._repos);
  final Repositories _repos;

  Future<UserSettingsRow> update(UserSettingsCompanion changes) async {
    final rows = await _repos.userSettings.getAll();
    if (rows.isEmpty) return _repos.userSettings.insert(changes);
    return _repos.userSettings.update(rows.first.id, changes);
  }

  Future<void> setLanguage(String code) =>
      update(UserSettingsCompanion(language: Value(code)));

  /// Region formats (PBI-035); null = follow the phone's region.
  Future<void> setCurrencySymbol(String? symbol) => update(
    UserSettingsCompanion(
      currencySymbol: Value(
        symbol == null || symbol.trim().isEmpty ? null : symbol.trim(),
      ),
    ),
  );

  Future<void> setWeekStart(int? weekday) =>
      update(UserSettingsCompanion(weekStart: Value(weekday)));

  Future<void> setDateOrder(String? order) =>
      update(UserSettingsCompanion(dateOrder: Value(order)));

  /// Greeting style (PBI-035). [custom] is kept even when switching styles,
  /// so coming back to Custom restores the user's word.
  Future<void> setGreeting(GreetStyle style, {String? custom}) =>
      update(UserSettingsCompanion(
        greetStyle: Value(style.name),
        greetCustom: custom == null ? const Value.absent() : Value(custom),
      ));

  /// "Show details on widget" (PBI-033 AC5).
  Future<void> setWidgetDetails(bool on) =>
      update(UserSettingsCompanion(widgetDetails: Value(on)));

  static const _widgetPromptKey = 'widget_details_prompted';

  /// Enabling App Lock offers to hide widget details exactly once
  /// (PBI-033 AC5). True only the first time.
  Future<bool> shouldPromptWidgetDetails() async {
    final db = _repos.db;
    final row = await (db.select(
      db.appMeta,
    )..where((m) => m.key.equals(_widgetPromptKey))).getSingleOrNull();
    if (row != null) return false;
    await db
        .into(db.appMeta)
        .insert(
          AppMetaCompanion.insert(key: _widgetPromptKey, value: '1'),
          mode: InsertMode.insertOrIgnore,
        );
    return true;
  }
}

/// Greeting style from the setting (PBI-035): neutral auto by default.
GreetStyle greetStyleOf(UserSettingsRow? s) =>
    GreetStyle.values.asNameMap()[s?.greetStyle] ?? GreetStyle.auto;

/// Region formats (PBI-035): the user's choices over the phone's defaults.
RegionFormats regionOf(UserSettingsRow? s) => resolveRegion(
  AppRegion.deviceLocale,
  symbol: s?.currencySymbol,
  weekStart: s?.weekStart,
  dateOrder: s?.dateOrder,
);

/// Points the pure helpers (money, dates, parser) at the settings. Called
/// by the app on every settings change, at start-up before anything writes
/// text, and in the notification isolate.
void applyRegion(UserSettingsRow? s) => AppRegion.current = regionOf(s);

/// App locale from the setting: English or Urdu (RTL).
Locale localeOf(UserSettingsRow? s) =>
    Locale(s?.language == 'ur' ? 'ur' : 'en');

ThemeMode themeModeOf(UserSettingsRow? s) => switch (s?.darkMode) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Look templates (PBI-025): Classic is for elders — large text.
enum LookTemplate { flagship, funky, classic }

LookTemplate templateOf(UserSettingsRow? s) => switch (s?.themeTemplate) {
  'funky' => LookTemplate.funky,
  'classic' => LookTemplate.classic,
  _ => LookTemplate.flagship,
};

/// Classic raises the text scale to at least 1.3× (AC4).
const classicTextScale = 1.3;

double textScaleOf(UserSettingsRow? s) {
  final base = s?.textScale ?? 1.0;
  return templateOf(s) == LookTemplate.classic && base < classicTextScale
      ? classicTextScale
      : base;
}
