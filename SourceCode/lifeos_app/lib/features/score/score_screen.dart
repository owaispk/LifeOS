import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../atc/atc_providers.dart' show allPaymentsProvider;
import '../money/ui/paid_sheet.dart';
import '../tasks/tasks_providers.dart' show taskServiceProvider;
import 'data/score_service.dart';
import 'domain/life_score.dart';
import 'score_providers.dart';
import 'ui/score_ring.dart';
import 'ui/sparkline.dart';

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// 1.1 Life Score detail (PBI-020): big ring, 7-day sparkline, component
/// bars and the exact items pulling the score down, each with a one-tap fix.
class ScoreScreen extends ConsumerStatefulWidget {
  const ScoreScreen({super.key});

  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = ref.watch(liveScoreProvider);
    final delta = ref.watch(scoreDeltaProvider);
    final now = ref.watch(nowProvider)();
    final snapshots =
        ref.watch(snapshotsProvider).value ?? const <ScoreSnapshot>[];
    final days = lastDays(snapshots, now, todayScore: score.score);
    final labels = [
      for (var i = 6; i >= 0; i--)
        _weekdayInitials[DateTime(now.year, now.month, now.day - i).weekday -
            1],
    ];
    final triage = score.triage && !_showAll;
    final drags = triage ? score.drags.take(3).toList() : score.drags;

    return Scaffold(
      appBar: AppBar(title: const Text('Life Score')),
      body: ListView(
        key: const ValueKey('score-list'),
        padding: const EdgeInsets.fromLTRB(
          Tokens.spaceM,
          Tokens.spaceS,
          Tokens.spaceM,
          120,
        ),
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoreRing(
                  score: score.score,
                  size: 168,
                  stroke: 14,
                  showLabel: true,
                ),
                const SizedBox(width: Tokens.spaceM),
                ScoreDelta(delta: delta),
              ],
            ),
          ),
          const SizedBox(height: Tokens.spaceL),
          Text('Last 7 days', style: theme.textTheme.titleSmall),
          const SizedBox(height: Tokens.spaceS),
          ScoreSparkline(values: days, dayLabels: labels),
          const SizedBox(height: Tokens.spaceL),
          Text("What's in it", style: theme.textTheme.titleSmall),
          const SizedBox(height: Tokens.spaceS),
          for (final c in score.components) _ComponentBar(c),
          const SizedBox(height: Tokens.spaceL),
          if (score.drags.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Tokens.spaceM),
                child: Text(
                  'Nothing is pulling your score down today ✓',
                  key: const ValueKey('score-clear'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            )
          else ...[
            Text(
              triage
                  ? 'Heavy week? Here are the 3 highest-impact items'
                  : 'What would lift it',
              key: const ValueKey('drags-title'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Tokens.spaceS),
            for (final d in drags) _DragTile(d),
            if (triage && score.drags.length > 3)
              TextButton(
                key: const ValueKey('drags-show-all'),
                onPressed: () => setState(() => _showAll = true),
                child: Text('Show all ${score.drags.length}'),
              ),
          ],
        ],
      ),
    );
  }
}

class _ComponentBar extends StatelessWidget {
  const _ComponentBar(this.c);
  final ComponentScore c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = (c.ratio * 100).round();
    return Padding(
      key: ValueKey('component-${c.component.name}'),
      padding: const EdgeInsets.symmetric(vertical: Tokens.spaceXs),
      child: Semantics(
        label:
            '${componentLabel(c.component)}: $pct percent, '
            '${c.weight.round()} percent of the score',
        excludeSemantics: true,
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                componentLabel(c.component),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: c.ratio,
                  minHeight: 8,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                '$pct% · ${c.weight.round()} pts',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragTile extends ConsumerWidget {
  const _DragTile(this.d);
  final Drag d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final points = d.points.abs();
    final pts = points == points.roundToDouble()
        ? points.round().toString()
        : points.toStringAsFixed(1);
    final (icon, fix) = switch (d.kind) {
      DragKind.overduePayment => ('💳', 'Mark paid'),
      DragKind.task => ('☑️', 'Move to today'),
      DragKind.expiringDocument => ('📄', 'Open'),
    };
    return Card(
      key: ValueKey('drag-${d.id}'),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [?d.detail, '+$pts when sorted'].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: FilledButton.tonal(
          key: ValueKey('fix-${d.id}'),
          onPressed: () => _fix(context, ref),
          child: Text(fix),
        ),
      ),
    );
  }

  Future<void> _fix(BuildContext context, WidgetRef ref) async {
    switch (d.kind) {
      case DragKind.overduePayment:
        final p = (ref.read(allPaymentsProvider).value ?? const <Payment>[])
            .where((x) => x.id == d.id)
            .firstOrNull;
        if (p != null) await payWithChain(context, ref, p);
      case DragKind.task:
        final now = ref.read(nowProvider)();
        await ref
            .read(taskServiceProvider)
            .reschedule(
              d.id,
              DateTime(now.year, now.month, now.day),
              allDay: true,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Moved to today')));
        }
      case DragKind.expiringDocument:
        await context.push('/doc/${d.id}');
    }
  }
}
