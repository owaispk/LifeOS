// Expiry Guard ladder (PBI-008) — pure, no database, no Flutter.
import 'dart:convert';

import '../../../core/region.dart';

/// Default alert ladders, in whole days before expiry (features spec §1.4).
const defaultLadder = [90, 30, 7, 1];
const travelLadder = [180, 90, 30]; // passport, visa
const billLadder = [3, 0, -1]; // 3 days before, the day, overdue +1

/// Reminders fire at this local hour.
const alertHour = 9;

/// The ladder for a document: its `expiry_alerts` override (a JSON list of
/// days) wins; otherwise the default for its type.
List<int> ladderFor(String docType, String? overrideJson) {
  if (overrideJson != null) {
    try {
      final list = (jsonDecode(overrideJson) as List).cast<int>();
      if (list.isNotEmpty) return list;
    } on Object {
      // fall back to the default
    }
  }
  return switch (docType) {
    'passport' || 'visa' => travelLadder,
    'bill' => billLadder,
    _ => defaultLadder,
  };
}

/// Calendar-safe "N days before [day] at 09:00" (handles month ends and
/// leap years by building from date parts, never from Durations).
DateTime alertAt(DateTime expiry, int daysBefore) =>
    DateTime(expiry.year, expiry.month, expiry.day - daysBefore, alertHour);

/// The ladder's alert times that are still in the future, soonest first.
List<DateTime> futureAlerts(DateTime expiry, List<int> ladder, DateTime now) {
  final times = {for (final d in ladder) alertAt(expiry, d)}
    ..removeWhere((t) => !t.isAfter(now));
  return times.toList()..sort();
}

/// 18:00 on the last day of the user's week, strictly after [now]: the
/// weekly nudge slot for expired documents (AC4 — at most one per week).
/// The evening before the week starts — Sunday for Monday weeks, Saturday
/// for Sunday weeks, Friday for Saturday weeks (PBI-035).
DateTime weeklyNudge(DateTime now, {int? weekStart}) {
  final start = weekStart ?? AppRegion.current.weekStart;
  final lastDay = (start + 5) % 7 + 1; // the weekday before [start]
  var d = DateTime(now.year, now.month, now.day, 18);
  while (d.weekday != lastDay || !d.isAfter(now)) {
    d = DateTime(d.year, d.month, d.day + 1, 18);
  }
  return d;
}

/// Types that usually expire: they get the one-time "Does this document
/// expire?" prompt when no date was found.
const expiringTypes = {
  'cnic',
  'passport',
  'visa',
  'license',
  'warranty',
  'policy',
};
