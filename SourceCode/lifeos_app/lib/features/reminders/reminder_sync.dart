import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../data/db/app_database.dart';
import '../../core/l10n.dart';
import '../home/domain/attention.dart' show GreetStyle, greetingText;
import '../settings/settings_providers.dart' show applyRegion;
import '../score/domain/life_score.dart';

import '../../data/repositories/repositories.dart';
import 'domain/reminder_planner.dart';
import 'platform/notification_gateway.dart';
import '../../core/log/app_log.dart';

/// Keeps the phone's scheduled notifications equal to the plan
/// (PBI-012 "rebuild-all"): on start, whenever tasks / reminders / payments
/// / settings change, and on app resume (timezone may have changed).
class ReminderSync {
  ReminderSync(
    this._repos,
    this._gateway, {
    DateTime Function()? now,
    this.debounce = const Duration(milliseconds: 300),
  }) : _now = now ?? DateTime.now;

  final Repositories _repos;
  final NotificationGateway _gateway;
  final DateTime Function() _now;
  final Duration debounce;

  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _timer;

  /// Rebuilds the schedule now. Returns what was scheduled.
  Future<List<PlannedNotification>> resync() async {
    final settings = (await _repos.userSettings.getAll()).firstOrNull;
    // Notification text follows the saved language — also in the
    // background isolate that handles notification actions.
    AppLocale.current = Locale(settings?.language == 'ur' ? 'ur' : 'en');
    applyRegion(settings); // amounts and dates in notifications (PBI-035)
    final tasks = await _repos.tasks.getAll();
    final payments = await _repos.payments.getAll();
    final now = _now();
    final prefs = settings == null
        ? const NotifyPrefs()
        : NotifyPrefs.fromSettings(
            quietStart: settings.quietStart,
            quietEnd: settings.quietEnd,
            digestTime: settings.digestTime,
            briefTime: settings.briefTime,
            briefEnabled: settings.briefEnabled,
            notifDomains: settings.notifDomains,
          );
    final planned = planNotifications(
      reminders: await _repos.taskReminders.getAll(),
      tasks: tasks,
      payments: payments,
      now: now,
      appLock: settings?.appLock ?? false,
      prefs: prefs,
      digest: await _digest(settings, tasks, payments, prefs.nextDigest(now)),
    );
    try {
      await _gateway.replaceAll(planned);
    } on Object catch (e, st) {
      AppLog.e('reminders', 'scheduling failed: ${e.runtimeType}', st);
      rethrow;
    }
    AppLog.i('reminders', 'scheduled ${planned.length}');
    return planned;
  }

  /// "Life Score 78 ↑3 · 5 tasks · 1 bill due" for the next digest
  /// (PBI-023), in the app's language. The score is computed for that
  /// morning from today's data; the change is against the last snapshot.
  Future<DigestText> _digest(
    UserSettingsRow? settings,
    List<Task> tasks,
    List<Payment> payments,
    DateTime at,
  ) async {
    final l = lookupAppLocalizations(
      Locale(settings?.language == 'ur' ? 'ur' : 'en'),
    );
    final score = computeLifeScore(
      tasks: tasks,
      payments: payments,
      documents: await _repos.documents.getAll(),
      now: at,
    ).score;
    final snaps = await _repos.scoreSnapshots.getAll()
      ..sort((a, b) => b.day.compareTo(a.day));
    final delta = snaps.isEmpty ? null : score - snaps.first.score;
    final scoreText = delta == null || delta == 0
        ? '$score'
        : '$score ${delta > 0 ? '↑' : '↓'}${delta.abs()}';
    final c = digestCounts(tasks: tasks, payments: payments, day: at);
    // The title is the user's greeting (PBI-035): neutral time-of-day by
    // default, or their chosen style — same words as the Home app bar.
    final title = greetingText(
      l,
      null,
      at,
      style:
          GreetStyle.values.asNameMap()[settings?.greetStyle] ??
          GreetStyle.auto,
      custom: settings?.greetCustom ?? '',
    );
    return DigestText(
      title,
      l.digestBody(scoreText, l.digestTasks(c.tasks), l.digestBills(c.bills)),
    );
  }

  /// Resyncs now, then after every relevant write (debounced).
  Future<void> start() async {
    await resync();
    final db = _repos.db;
    _sub = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.tasks,
            db.taskReminders,
            db.payments,
            db.userSettings,
            db.documents,
            db.scoreSnapshots,
          ]),
        )
        .listen((_) {
          _timer?.cancel();
          _timer = Timer(debounce, resync);
        });
  }

  /// App came back to the foreground: the timezone or clock may differ.
  Future<void> onResume() async {
    await _gateway.refreshTimezone();
    await resync();
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _sub?.cancel();
  }
}
