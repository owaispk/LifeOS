import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/repositories.dart';

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
}

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
