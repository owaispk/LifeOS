// Full-screen brief display (PBI-039a).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../premium/premium_providers.dart';
import '../../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../../score/ui/score_ring.dart';
import '../../settings/settings_providers.dart';
import '../brief_providers.dart';

/// Route for the brief screen.
const briefRoute = '/brief';

/// Full-screen brief card with TTS playback.
class BriefScreen extends ConsumerStatefulWidget {
  const BriefScreen({super.key});

  @override
  ConsumerState<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends ConsumerState<BriefScreen> {
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(briefSettingsProvider);
    final lang = ref.read(settingsProvider).value?.language ?? 'en';

    await tts.init(
      TtsConfig(
        rate: settings.ttsRate,
        language: ttsLanguageFor(lang),
      ),
    );

    tts.onComplete = () {
      if (mounted) setState(() => _isSpeaking = false);
    };

    tts.onCancel = () {
      if (mounted) setState(() => _isSpeaking = false);
    };
  }

  Future<void> _speak() async {
    final tts = ref.read(ttsServiceProvider);

    if (_isSpeaking) {
      await tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final text = await ref.read(briefTextProvider.future);
    setState(() => _isSpeaking = true);
    await tts.speak(text);
  }

  @override
  void dispose() {
    ref.read(ttsServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final premium = ref.watch(premiumProvider);
    final data = ref.watch(briefDataProvider);
    final briefText = ref.watch(briefTextProvider);
    final aiAvailable = ref.watch(briefAiAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.briefTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            key: const ValueKey('brief-settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.moreSettings,
            onPressed: () => context.push('/more/settings/brief'),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l.briefError, style: theme.textTheme.bodyLarge),
        ),
        data: (briefData) => SingleChildScrollView(
          padding: EdgeInsets.all(Tokens.spaceL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Score ring
              Center(
                child: ScoreRing(
                  score: briefData.lifeScore,
                  size: 120,
                ),
              ),
              SizedBox(height: Tokens.spaceL),

              // Brief text card
              Card(
                key: const ValueKey('brief-card'),
                child: Padding(
                  padding: EdgeInsets.all(Tokens.spaceL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (aiAvailable)
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: Tokens.iconS,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: Tokens.spaceXs),
                            Text(
                              l.briefAiGenerated,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      if (aiAvailable) SizedBox(height: Tokens.spaceS),
                      briefText.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (_, _) => Text(
                          generatePlainTextBrief(briefData),
                          style: theme.textTheme.bodyLarge,
                        ),
                        data: (text) => Text(
                          text,
                          key: const ValueKey('brief-text'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: Tokens.spaceL),

              // Speak button
              FilledButton.icon(
                key: const ValueKey('brief-speak'),
                onPressed: _speak,
                icon: Icon(
                  _isSpeaking ? Icons.stop : Icons.volume_up,
                ),
                label: Text(_isSpeaking ? l.briefStop : l.briefSpeak),
              ),
              SizedBox(height: Tokens.spaceM),

              // Stats row
              _StatsRow(data: briefData),

              // Premium upsell if needed
              if (!premium) ...[
                SizedBox(height: Tokens.spaceL),
                _PremiumUpsell(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final BriefData data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.all(Tokens.spaceM),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.check_circle_outline,
              value: '${data.taskCount}',
              label: l.briefStatTasks,
            ),
            _StatItem(
              icon: Icons.warning_amber_outlined,
              value: '${data.overduePayments}',
              label: l.briefStatOverdue,
              isWarning: data.overduePayments > 0,
            ),
            _StatItem(
              icon: Icons.schedule,
              value: '${data.expiringDocs}',
              label: l.briefStatExpiring,
              isWarning: data.expiringDocs > 0,
            ),
            if (data.monthlyBudget > 0)
              _StatItem(
                icon: Icons.account_balance_wallet_outlined,
                value: '${data.budgetUsedPercent}%',
                label: l.briefStatBudget,
                isWarning: data.isBudgetCritical,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isWarning
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Icon(icon, color: color, size: Tokens.iconL),
        SizedBox(height: Tokens.spaceXs),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PremiumUpsell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: EdgeInsets.all(Tokens.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                SizedBox(width: Tokens.spaceS),
                Expanded(
                  child: Text(
                    l.briefPremiumTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Tokens.spaceS),
            Text(
              l.briefPremiumBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            SizedBox(height: Tokens.spaceM),
            TextButton(
              onPressed: () => context.push(premiumRoute),
              child: Text(l.pmSeePremium),
            ),
          ],
        ),
      ),
    );
  }
}
