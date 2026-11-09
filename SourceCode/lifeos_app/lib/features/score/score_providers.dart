import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import '../atc/atc_providers.dart' show allPaymentsProvider;
import '../tasks/tasks_providers.dart' show allTasksProvider;
import '../vault/vault_providers.dart' show documentsProvider;
import '../settings/settings_providers.dart';
import 'data/score_service.dart';
import 'domain/life_score.dart';

/// Weights in use; `main` loads them from `assets/score_weights.json`.
final scoreWeightsProvider = Provider<ScoreWeights>((ref) => ScoreWeights.v1);

final scoreServiceProvider = Provider<ScoreService>(
  (ref) => ScoreService(
    ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider),
    weights: ref.watch(scoreWeightsProvider),
  ),
);

/// Today's score, live: recomputed whenever tasks, payments or documents
/// change. Before data loads (and on the web preview) it is the
/// nothing-to-punish 100.
final liveScoreProvider = Provider<LifeScore>((ref) {
  // Drag details are worded in the app's language: recompute on a switch.
  ref.watch(settingsProvider.select((s) => s.value?.language));
  return computeLifeScore(
    tasks: ref.watch(allTasksProvider).value ?? const <Task>[],
    payments: ref.watch(allPaymentsProvider).value ?? const <Payment>[],
    documents: ref.watch(documentsProvider).value ?? const <Document>[],
    now: ref.watch(nowProvider)(),
    weights: ref.watch(scoreWeightsProvider),
  );
});

/// Every daily snapshot, live.
final snapshotsProvider = StreamProvider<List<ScoreSnapshot>>(
  (ref) => ref.watch(repositoriesProvider).scoreSnapshots.watchAll(),
);

/// Today − yesterday's snapshot, or null without one.
final scoreDeltaProvider = Provider<int?>((ref) {
  final now = ref.watch(nowProvider)();
  final y = DateTime(now.year, now.month, now.day - 1);
  final key =
      '${y.year.toString().padLeft(4, '0')}-'
      '${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  final prev = (ref.watch(snapshotsProvider).value ?? const <ScoreSnapshot>[])
      .where((s) => s.day == key)
      .firstOrNull;
  return prev == null ? null : ref.watch(liveScoreProvider).score - prev.score;
});
