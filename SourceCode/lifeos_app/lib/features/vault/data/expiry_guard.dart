import 'dart:async';

import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/domain/money_rules.dart' show parseIsoDate;
import '../domain/expiry_ladder.dart';

/// Expiry Guard (PBI-008): keeps one renewal task per expiring document,
/// with reminders that follow the ladder. Reconciles from the documents —
/// idempotent, so it can run at start and after any document change.
class ExpiryGuard {
  ExpiryGuard(this._repos, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;

  StreamSubscription<Set<TableUpdate>>? _sub;
  Timer? _timer;

  AppDatabase get _db => _repos.db;

  /// The renewal task for [docId]: domain `vault`, linked to the document,
  /// not created by an ATC rule.
  Future<Task?> renewalTaskFor(String docId) async {
    final tasks = await _repos.tasks.getWhere(
      (t) =>
          t.sourceDocumentId.equals(docId) &
          t.domain.equals('vault') &
          t.atcRuleId.isNull() &
          t.status.equals('open'),
    );
    return tasks.firstOrNull;
  }

  /// Brings every document's renewal task + reminders in line with its
  /// expiry date. Returns the number of documents being guarded.
  Future<int> reconcile() {
    return _db.transaction(() async {
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      final docs = await _repos.documents.getAll(includeDeleted: true);
      final guarded = docs
          .where(
            (d) =>
                d.deletedAt == null &&
                d.archivedAt == null &&
                d.expiryDate != null,
          )
          .toList();
      // Only the most overdue expired document carries the weekly nudge:
      // at most one nudge per week overall (AC4).
      final expired =
          guarded
              .where((d) => parseIsoDate(d.expiryDate!).isBefore(today))
              .toList()
            ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
      final nudgeFor = expired.firstOrNull?.id;

      for (final d in docs) {
        final isGuarded = guarded.contains(d);
        var task = await renewalTaskFor(d.id);
        if (!isGuarded) {
          if (task != null) await _removeTask(task);
          continue;
        }
        final expiry = parseIsoDate(d.expiryDate!);
        final title = 'Renew ${d.title}';
        if (task == null) {
          task = await _repos.tasks.insert(
            TasksCompanion.insert(
              title: title,
              domain: const Value('vault'),
              sourceDocumentId: Value(d.id),
              personId: Value(d.personId),
              dueAt: Value(expiry.millisecondsSinceEpoch),
              priority: const Value(2),
              durationMin: const Value(30),
            ),
          );
        } else if (task.dueAt != expiry.millisecondsSinceEpoch ||
            task.title != title) {
          task = await _repos.tasks.update(
            task.id,
            TasksCompanion(
              title: Value(title),
              dueAt: Value(expiry.millisecondsSinceEpoch),
            ),
          );
        }

        final wanted = expiry.isBefore(today)
            ? (d.id == nudgeFor ? [weeklyNudge(now)] : const <DateTime>[])
            : futureAlerts(expiry, ladderFor(d.docType, d.expiryAlerts), now);
        await _syncReminders(task.id, wanted);
      }
      return guarded.length;
    });
  }

  /// Makes the task's unfired reminders exactly [wanted] — no duplicates
  /// after a date change (AC2).
  Future<void> _syncReminders(String taskId, List<DateTime> wanted) async {
    final existing = await _repos.taskReminders.getWhere(
      (r) => r.taskId.equals(taskId) & r.fired.equals(false),
    );
    final want = {for (final w in wanted) w.millisecondsSinceEpoch};
    final have = <int>{};
    for (final r in existing) {
      if (!want.contains(r.fireAt) || !have.add(r.fireAt)) {
        await _repos.taskReminders.softDelete(r.id);
      }
    }
    for (final ms in want.difference(have)) {
      await _repos.taskReminders.insert(
        TaskRemindersCompanion.insert(taskId: taskId, fireAt: ms),
      );
    }
  }

  Future<void> _removeTask(Task task) async {
    for (final r in await _repos.taskReminders.getWhere(
      (r) => r.taskId.equals(task.id),
    )) {
      await _repos.taskReminders.softDelete(r.id);
    }
    await _repos.tasks.softDelete(task.id);
  }

  /// Reconciles now and after every document change (debounced).
  Future<void> start({
    Duration debounce = const Duration(milliseconds: 400),
  }) async {
    await reconcile();
    _sub = _db.tableUpdates(TableUpdateQuery.onTable(_db.documents)).listen((
      _,
    ) {
      _timer?.cancel();
      _timer = Timer(debounce, reconcile);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    await _sub?.cancel();
  }
}
