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
import '../calendar/calendar_providers.dart';
import '../capture/capture_entry.dart';
import '../score/score_providers.dart';
import '../score/ui/score_ring.dart';
import '../inbox/inbox_providers.dart' show pendingCountProvider;
import '../settings/settings_providers.dart'
    show greetStyleOf, settingsProvider;
import '../tasks/domain/task_rules.dart';
import '../tasks/tasks_providers.dart' show allTasksProvider;
import '../tasks/ui/new_task_sheet.dart';
import '../tasks/ui/task_tile.dart';
import '../vault/vault_providers.dart' show documentsProvider;
import '../brief/ui/brief_button.dart';
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
    final settings = ref.watch(settingsProvider).value;
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
    // Device-calendar events count towards the one morning check
    // (PBI-032); they are never tasks.
    final events = ref.watch(todayEventsProvider);
    final week = weekPaymentsMinor(payments, now);
    final isNew = tasks.isEmpty && docs.isEmpty && rules.isEmpty;
    final l = context.l10n;

    final inboxCount = ref.watch(pendingCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          greeting(
            self,
            now,
            style: greetStyleOf(settings),
            custom: settings?.greetCustom ?? '',
          ),
          key: const ValueKey('home-greeting'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('home-inbox'),
            tooltip: l.inboxTitle,
            onPressed: () => context.go('/inbox'),
            icon: Badge(
              isLabelVisible: inboxCount > 0,
              label: Text('$inboxCount'),
              child: const Icon(Icons.inbox_outlined),
            ),
          ),
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
            tooltip: l.mrProfile,
            onPressed: () => context.go('/more/profile'),
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
          padding: EdgeInsets.only(bottom: Tokens.listEnd),
          children: [
            _ScoreCard(
              score: score.score,
              delta: delta,
              attentionCount: attention.length,
            ),
            // Daily Voice Brief button (PBI-039a)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Tokens.gutter,
                vertical: Tokens.spaceS,
              ),
              child: const BriefButton(),
            ),
            if (isNew)
              const _NewUserPrompts()
            else ...[
              _SectionTitle(
                key: const ValueKey('home-attention'),
                l.hmAttentionSection,
                action: attention.length > attentionCap
                    ? _SeeAll(
                        key: const ValueKey('attention-see-all'),
                        label: l.hmSeeAllCount('${attention.length}'),
                        onTap: () => context.go('/home/attention'),
                      )
                    : null,
              ),
              if (attention.isEmpty)
                _FriendlyLine(
                  key: const ValueKey('attention-empty'),
                  l.hmNothingUrgentNice,
                )
              else ...[
                for (final item in attention.take(attentionCap))
                  AttentionTile(item: item),
              ],
              _SectionTitle(
                key: const ValueKey('home-today'),
                events.isEmpty
                    ? l.hmTodayTasks(today.length)
                    : l.hmTodayTasksEvents(
                        l.digestTasks(today.length),
                        l.calCount(events.length),
                      ),
                action: today.length > homeTaskCap
                    ? _SeeAll(
                        key: const ValueKey('today-see-all'),
                        label: l.hmSeeAllN('${today.length}'),
                        onTap: () => context.go('/tasks'),
                      )
                    : null,
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
              ],
              // One compact row on the gutter: the card's theme margin is
              // the only spacing (PBI-031).
              Padding(
                padding: EdgeInsets.only(top: Tokens.spaceS),
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
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.gutter,
          vertical: Tokens.spaceS,
        ),
        child: Row(
          children: [
            ScoreRing(
              score: score,
              size: AppSpacing.current.isCompact ? 80 : 96,
            ),
            SizedBox(width: Tokens.spaceS),
            ScoreDelta(delta: delta),
            SizedBox(width: Tokens.spaceM),
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

/// A section header on the gutter, with an optional "See all" at the end
/// of the same line (PBI-031: no extra row for it).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: Tokens.gutter,
        top: Tokens.spaceM,
        // The action's own padding supplies the end gap.
        end: action == null ? Tokens.gutter : Tokens.gutter - 12,
      ),
      child: SizedBox(
        height: Tokens.minTouchTarget,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _SeeAll extends StatelessWidget {
  const _SeeAll({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onTap, child: Text(label));
}

class _FriendlyLine extends StatelessWidget {
  const _FriendlyLine(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
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
      padding: EdgeInsets.all(Tokens.spaceM),
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
