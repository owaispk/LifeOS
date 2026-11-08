import 'dart:async';

import 'package:drift/drift.dart';

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
    final settings = await _repos.userSettings.getAll();
    final planned = planNotifications(
      reminders: await _repos.taskReminders.getAll(),
      tasks: await _repos.tasks.getAll(),
      payments: await _repos.payments.getAll(),
      now: _now(),
      appLock: settings.isNotEmpty && settings.first.appLock,
    );
    await _gateway.replaceAll(planned);
    return planned;
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
