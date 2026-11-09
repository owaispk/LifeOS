import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../core/l10n.dart';
import '../../core/log/app_log.dart';
import '../../data/repositories/repositories.dart';
import '../score/domain/life_score.dart';
import '../settings/settings_providers.dart' show applyRegion;
import 'domain/widget_snapshot.dart';
import 'platform/widget_gateway.dart';

/// Keeps the home-screen widget equal to the data (PBI-033): one push at
/// start, after every relevant write (debounced ~1 s so a batch writes
/// once) and on app pause. No polling — battery-friendly.
class WidgetSync {
  WidgetSync(
    this._repos,
    this._gateway, {
    this.weights = ScoreWeights.v1,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now;

  final Repositories _repos;
  final WidgetGateway _gateway;
  final ScoreWeights weights;
  final DateTime Function() _now;
  final Duration debounce;

  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _timer;

  /// Builds and pushes the snapshot now. Never throws (AC7): a launcher
  /// or plugin failure is one log entry, and the app moves on.
  Future<void> push() async {
    try {
      final settings = (await _repos.userSettings.getAll()).firstOrNull;
      // Widget text follows the saved language and region formats, like
      // notifications (PBI-012/035).
      AppLocale.current = Locale(settings?.language == 'ur' ? 'ur' : 'en');
      applyRegion(settings);
      final now = _now();
      final snapshot = buildWidgetSnapshot(
        tasks: await _repos.tasks.getAll(),
        payments: await _repos.payments.getAll(),
        documents: await _repos.documents.getAll(),
        now: now,
        weights: weights,
        details: settings?.widgetDetails ?? true,
        rtl: settings?.language == 'ur',
      );
      await _gateway.push(
        snapshot.toJsonString(),
        nextMidnight: DateTime(now.year, now.month, now.day + 1, 0, 5),
      );
      AppLog.i('widget', 'pushed ${snapshot.day}');
    } on Object catch (e, st) {
      AppLog.e('widget', 'push failed: ${e.runtimeType}', st);
    }
  }

  /// Pushes now, then after every relevant write (debounced).
  Future<void> start() async {
    await push();
    final db = _repos.db;
    _sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.tasks,
            db.payments,
            db.documents,
            db.scoreSnapshots,
            db.userSettings,
          ]),
        )
        .listen((_) {
          _timer?.cancel();
          _timer = Timer(debounce, push);
        });
  }

  /// The app is leaving the foreground: freshen the widget one last time.
  Future<void> onPause() => push();

  Future<void> stop() async {
    _timer?.cancel();
    await _sub?.cancel();
  }
}
