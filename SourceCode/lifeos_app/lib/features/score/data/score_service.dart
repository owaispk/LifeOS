import '../../../data/db/app_database.dart';
import '../../../data/repositories/repositories.dart';
import '../../money/domain/money_rules.dart' show isoDate;
import '../domain/life_score.dart';

/// Today's score with the change since yesterday's snapshot.
class ScoreToday {
  const ScoreToday(this.score, this.delta);
  final LifeScore score;

  /// Today − yesterday, or null when there is no snapshot for yesterday.
  final int? delta;
}

/// Computes the Life Score from the database and keeps one snapshot per
/// day (PBI-020 AC5).
class ScoreService {
  ScoreService(
    this._repos, {
    DateTime Function()? now,
    this.weights = ScoreWeights.v1,
  }) : _now = now ?? DateTime.now;

  final Repositories _repos;
  final DateTime Function() _now;
  final ScoreWeights weights;

  Future<LifeScore> compute() async => computeLifeScore(
    tasks: await _repos.tasks.getAll(),
    payments: await _repos.payments.getAll(),
    documents: await _repos.documents.getAll(),
    now: _now(),
    weights: weights,
  );

  /// Computes today's score and upserts today's snapshot: computing twice
  /// on one day leaves one row.
  Future<ScoreToday> refresh() async {
    final score = await compute();
    final today = _now();
    final day = isoDate(today);
    // No transaction: one read and one write, and the (user_id, day)
    // unique key keeps it to one row per day. (A transaction would hold
    // the database lock across awaits while Home opens.)
    final existing = await _repos.scoreSnapshots.getWhere(
      (s) => s.day.equals(day),
    );
    final row = ScoreSnapshotsCompanion.insert(
      day: day,
      score: score.score,
      components: score.componentsJson(),
      drags: score.dragsJson(),
    );
    if (existing.isEmpty) {
      await _repos.scoreSnapshots.insert(row);
    } else {
      await _repos.scoreSnapshots.update(existing.first.id, row);
    }
    final yesterday = isoDate(DateTime(today.year, today.month, today.day - 1));
    final prev = await _repos.scoreSnapshots.getWhere(
      (s) => s.day.equals(yesterday),
    );
    return ScoreToday(
      score,
      prev.isEmpty ? null : score.score - prev.first.score,
    );
  }
}

/// Score per day for the last [days] days ending today (oldest first);
/// days without a snapshot are null. [todayScore] stands in for today.
List<int?> lastDays(
  List<ScoreSnapshot> snapshots,
  DateTime now, {
  int days = 7,
  int? todayScore,
}) {
  final byDay = {for (final s in snapshots) s.day: s.score};
  return [
    for (var i = days - 1; i >= 0; i--)
      i == 0 && todayScore != null
          ? todayScore
          : byDay[isoDate(DateTime(now.year, now.month, now.day - i))],
  ];
}
