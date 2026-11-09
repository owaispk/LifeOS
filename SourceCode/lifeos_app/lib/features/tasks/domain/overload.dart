// Overload Shield (PBI-011) — pure capacity maths, no Flutter.
import '../../../core/region.dart';
import '../../../data/db/app_database.dart';
import 'task_rules.dart';

const defaultDayCapacityMin = 360; // 6 h
const suggestionHorizonDays = 14;

/// One day's planned load.
class DayLoad {
  const DayLoad(this.day, this.loadMin, this.capacityMin);

  final DateTime day;
  final int loadMin;
  final int capacityMin;

  /// Whole percent of capacity (rounded half-up).
  int get percent =>
      capacityMin <= 0 ? 0 : ((loadMin * 200) ~/ capacityMin + 1) ~/ 2;

  bool get isFull => loadMin > capacityMin;
}

/// Sum of `duration_min` of open tasks due on [day] (local).
int dayLoadMin(List<Task> tasks, DateTime day, {String? excludeTaskId}) {
  final d = startOfDay(day);
  var sum = 0;
  for (final t in tasks) {
    if (!isOpen(t) || t.dueAt == null || t.id == excludeTaskId) continue;
    if (startOfDay(localDue(t)) == d) sum += t.durationMin;
  }
  return sum;
}

List<DayLoad> loadsFrom(
  List<Task> tasks,
  DateTime start,
  int days,
  int capacityMin, {
  String? excludeTaskId,
}) {
  final first = startOfDay(start);
  return [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(first.year, first.month, first.day + i);
        return DayLoad(
          day,
          dayLoadMin(tasks, day, excludeTaskId: excludeTaskId),
          capacityMin,
        );
      }(),
  ];
}

/// The week containing [day], starting on the user's first day of the week
/// (PBI-035).
List<DayLoad> weekOf(
  List<Task> tasks,
  DateTime day,
  int capacityMin, {
  String? excludeTaskId,
  int? weekStart,
}) {
  final d = startOfDay(day);
  final start = weekStart ?? AppRegion.current.weekStart;
  final first = DateTime(d.year, d.month, d.day - (d.weekday - start) % 7);
  return loadsFrom(tasks, first, 7, capacityMin, excludeTaskId: excludeTaskId);
}

/// Nearest day after [day] (never before today) whose current load is under
/// 70% and that still fits the task within 100%. Null if none within
/// [suggestionHorizonDays].
DateTime? suggestDay(
  List<Task> tasks, {
  required DateTime day,
  required int durationMin,
  required int capacityMin,
  required DateTime now,
  String? excludeTaskId,
}) {
  final today = startOfDay(now);
  var from = startOfDay(day);
  // Placing on a past day: start the search at today (loop adds 1).
  if (from.isBefore(today)) {
    from = DateTime(today.year, today.month, today.day - 1);
  }
  for (var i = 1; i <= suggestionHorizonDays; i++) {
    final candidate = DateTime(from.year, from.month, from.day + i);
    final load = dayLoadMin(tasks, candidate, excludeTaskId: excludeTaskId);
    // load < 70% of capacity, in integers: load * 10 < capacity * 7.
    if (load * 10 < capacityMin * 7 && load + durationMin <= capacityMin) {
      return candidate;
    }
  }
  return null;
}

/// Result of checking a task against the day it's being placed on.
class OverloadCheck {
  const OverloadCheck({
    required this.day,
    required this.loadWithTaskMin,
    required this.capacityMin,
    required this.suggested,
    required this.week,
  });

  final DateTime day;
  final int loadWithTaskMin;
  final int capacityMin;
  final DateTime? suggested;

  /// The day's week (from the user's first day), including the new task.
  final List<DayLoad> week;
}

/// Returns a check when placing a task of [durationMin] on [day] would push
/// it over capacity; null when it fits, when the task is undated, or when it
/// is an ATC task (bills don't negotiate — they count but never block).
OverloadCheck? checkOverload({
  required List<Task> tasks,
  required DateTime? day,
  required int durationMin,
  required int capacityMin,
  required DateTime now,
  bool isAtc = false,
  String? excludeTaskId,
}) {
  if (day == null || isAtc) return null;
  final load = dayLoadMin(tasks, day, excludeTaskId: excludeTaskId);
  final withTask = load + durationMin;
  if (withTask <= capacityMin) return null;

  final target = startOfDay(day);
  final week = [
    for (final d in weekOf(
      tasks,
      day,
      capacityMin,
      excludeTaskId: excludeTaskId,
    ))
      d.day == target
          ? DayLoad(d.day, d.loadMin + durationMin, capacityMin)
          : d,
  ];
  return OverloadCheck(
    day: target,
    loadWithTaskMin: withTask,
    capacityMin: capacityMin,
    suggested: suggestDay(
      tasks,
      day: day,
      durationMin: durationMin,
      capacityMin: capacityMin,
      now: now,
      excludeTaskId: excludeTaskId,
    ),
    week: week,
  );
}

/// "6.5h", "6h", "45m".
String formatHours(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final tenths = ((minutes * 20) ~/ 60 + 1) ~/ 2; // hours ×10, half-up
  return tenths % 10 == 0
      ? '${tenths ~/ 10}h'
      : '${tenths ~/ 10}.${tenths % 10}h';
}
