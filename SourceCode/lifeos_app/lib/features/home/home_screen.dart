import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/money.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/data_providers.dart' show personsProvider;
import '../../data/db/app_database.dart';
import '../atc/atc_providers.dart' show allPaymentsProvider, atcRulesProvider;
import '../atc/ui/rule_form.dart' show showAddRuleSheet;
import '../capture/capture_entry.dart';
import '../score/score_providers.dart';
import '../score/ui/score_ring.dart';
import '../tasks/domain/task_rules.dart';
import '../tasks/tasks_providers.dart' show allTasksProvider;
import '../tasks/ui/new_task_sheet.dart';
import '../tasks/ui/task_tile.dart';
import '../vault/vault_providers.dart' show documentsProvider;
import 'domain/attention.dart';
import 'ui/attention_tile.dart';

/// Today's tasks shown on Home before "See all".
const homeTaskCap = 5;

/// Everything that needs attention, most urgent first (live).
final attentionProvider = Provider<List<AttentionItem>>(
  (ref) => attentionItems(
    payments: ref.watch(allPaymentsProvider).value ?? const <Payment>[],
    documents: ref.watch(documentsProvider).value ?? const <Document>[],
    now: ref.watch(nowProvider)(),
  ),
);

/// 1. HOME — dashboard (PBI-021): greeting, Life Score, Needs Attention,
/// today's tasks, the week's payments. One screen before scrolling.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Recomputes the score and writes today's snapshot (pull-to-refresh).
  Future<void> _refresh() async {
    try {
      await ref.read(scoreServiceProvider).refresh();
    } on Object {
      // No local database (web preview): the live score still shows.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final self = persons.where((p) => p.relation == 'self').firstOrNull;
    final score = ref.watch(liveScoreProvider);
    final delta = ref.watch(scoreDeltaProvider);
    final attention = ref.watch(attentionProvider);
    final tasks = ref.watch(allTasksProvider).value ?? const <Task>[];
    final payments = ref.watch(allPaymentsProvider).value ?? const <Payment>[];
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final rules = ref.watch(atcRulesProvider).value ?? const <AtcRule>[];
    final today = todaySections(tasks, now).values.expand((l) => l).toList();
    final week = weekPaymentsMinor(payments, now);
    final isNew = tasks.isEmpty && docs.isEmpty && rules.isEmpty;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(greeting(self), key: const ValueKey('home-greeting')),
        actions: [
          IconButton(
            key: const ValueKey('home-bell'),
            tooltip: l.hmNeedsAttention,
            onPressed: () => context.go('/home/attention'),
            icon: Badge(
              isLabelVisible: attention.isNotEmpty,
              label: Text('${attention.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            key: const ValueKey('home-profile'),
            tooltip: l.hmProfileMore,
            onPressed: () => context.go('/more'),
            icon: Text(
              self?.avatar ?? '👤',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: const ValueKey('home-refresh'),
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('home-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _ScoreCard(
              score: score.score,
              delta: delta,
              attentionCount: attention.length,
            ),
            if (isNew)
              const _NewUserPrompts()
            else ...[
              _SectionTitle(
                key: const ValueKey('home-attention'),
                l.hmAttentionSection,
              ),
              if (attention.isEmpty)
                _FriendlyLine(
                  key: const ValueKey('attention-empty'),
                  l.hmNothingUrgentNice,
                )
              else ...[
                for (final item in attention.take(attentionCap))
                  AttentionTile(item: item),
                if (attention.length > attentionCap)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('attention-see-all'),
                      onPressed: () => context.go('/home/attention'),
                      child: Text(l.hmSeeAllCount('${attention.length}')),
                    ),
                  ),
              ],
              _SectionTitle(
                key: const ValueKey('home-today'),
                l.hmTodayTasks(today.length),
              ),
              if (today.isEmpty)
                _FriendlyLine(
                  key: const ValueKey('today-empty'),
                  l.hmClearDay,
                  action: TextButton(
                    onPressed: () => showNewTaskSheet(context),
                    child: Text(l.hmAddTask),
                  ),
                )
              else ...[
                for (final t in today.take(homeTaskCap))
                  TaskTile(task: t, showDomain: false),
                if (today.length > homeTaskCap)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: const ValueKey('today-see-all'),
                      onPressed: () => context.go('/tasks'),
                      child: Text(l.hmSeeAllN('${today.length}')),
                    ),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.all(Tokens.spaceM),
                child: Card(
                  key: const ValueKey('home-money'),
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: ListTile(
                    leading: const Text('💰', style: TextStyle(fontSize: 22)),
                    title: Text(
                      week == 0
                          ? l.hmNoPaymentsWeek
                          : l.hmPaymentsWeek(Money.format(week)),
                      key: const ValueKey('home-money-text'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/money'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.delta,
    required this.attentionCount,
  });

  final int score;
  final int? delta;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return InkWell(
      key: const ValueKey('home-score'),
      onTap: () => context.go('/home/score'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.spaceM,
          vertical: Tokens.spaceS,
        ),
        child: Row(
          children: [
            ScoreRing(score: score, size: 96),
            const SizedBox(width: Tokens.spaceS),
            ScoreDelta(delta: delta),
            const SizedBox(width: Tokens.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.scLifeScore, style: theme.textTheme.labelLarge),
                  Text(
                    attentionCount == 0
                        ? l.hmAllClear
                        : l.hmThingsNeedAttention(attentionCount),
                    key: const ValueKey('home-attention-count'),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.spaceM,
        Tokens.spaceM,
        Tokens.spaceM,
        Tokens.spaceXs,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FriendlyLine extends StatelessWidget {
  const _FriendlyLine(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceM),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// AC4: a brand-new user sees friendly prompts, not empty sections.
class _NewUserPrompts extends StatelessWidget {
  const _NewUserPrompts();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final prompts = [
      (
        'prompt-scan',
        l.hmPromptScanTitle,
        l.hmPromptScanBody,
        () => startScan(context),
      ),
      (
        'prompt-atc',
        l.hmPromptAtcTitle,
        l.hmPromptAtcBody,
        () => showAddRuleSheet(context),
      ),
      (
        'prompt-task',
        l.hmPromptTaskTitle,
        l.hmPromptTaskBody,
        () => showNewTaskSheet(context),
      ),
    ];
    return Padding(
      key: const ValueKey('home-prompts'),
      padding: const EdgeInsets.all(Tokens.spaceM),
      child: Column(
        children: [
          for (final p in prompts)
            Card(
              child: ListTile(
                key: ValueKey(p.$1),
                title: Text(p.$2),
                subtitle: Text(p.$3),
                trailing: const Icon(Icons.chevron_right),
                onTap: p.$4,
              ),
            ),
        ],
      ),
    );
  }
}
