import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../data/db/app_database.dart';
import '../../core/l10n.dart';
import '../score/domain/life_score.dart';

import '../../data/repositories/repositories.dart';
import 'domain/reminder_planner.dart';
import 'platform/notification_gateway.dart';

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
    final tasks = await _repos.tasks.getAll();
    final payments = await _repos.payments.getAll();
    final now = _now();
    final prefs = settings == null
        ? const NotifyPrefs()
        : NotifyPrefs.fromSettings(
            quietStart: settings.quietStart,
            quietEnd: settings.quietEnd,
            digestTime: settings.digestTime,
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
    await _gateway.replaceAll(planned);
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
    return DigestText(
      l.digestTitle,
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
