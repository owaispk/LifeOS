// Brief settings screen (PBI-039a).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../premium/premium_providers.dart';
import '../../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../../settings/settings_providers.dart';
import '../brief_providers.dart';

/// Route for brief settings.
const briefSettingsRoute = '/more/settings/brief';

/// Settings screen for brief time, TTS rate, and AI consent.
class BriefSettingsScreen extends ConsumerStatefulWidget {
  const BriefSettingsScreen({super.key});

  @override
  ConsumerState<BriefSettingsScreen> createState() =>
      _BriefSettingsScreenState();
}

class _BriefSettingsScreenState extends ConsumerState<BriefSettingsScreen> {
  double _rate = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(briefSettingsProvider);
      setState(() => _rate = settings.ttsRate);
    });
  }

  Future<void> _pickTime() async {
    final current = ref.read(briefSettingsProvider).briefTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current.inHours,
        minute: current.inMinutes % 60,
      ),
    );
    if (picked != null && mounted) {
      await ref.read(briefSettingsServiceProvider).setBriefTime(
        Duration(hours: picked.hour, minutes: picked.minute),
      );
    }
  }

  Future<void> _testTts() async {
    final tts = ref.read(ttsServiceProvider);
    final lang = ref.read(settingsProvider).value?.language ?? 'en';
    final testText = context.l10n.briefTtsTest;
    await tts.init(TtsConfig(rate: _rate, language: ttsLanguageFor(lang)));
    if (!mounted) return;
    await tts.speak(testText);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(briefSettingsProvider);
    final premium = ref.watch(premiumProvider);
    final aiAvailable = ref.watch(briefAiAvailableProvider);

    final timeString =
        '${settings.briefTime.inHours.toString().padLeft(2, '0')}:'
        '${(settings.briefTime.inMinutes % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: Text(l.briefSettingsTitle)),
      body: ListView(
        key: const ValueKey('brief-settings-list'),
        padding: EdgeInsets.all(Tokens.spaceL),
        children: [
          // Brief enabled
          SwitchListTile(
            key: const ValueKey('brief-enabled'),
            title: Text(l.briefEnabled),
            subtitle: Text(l.briefEnabledSub),
            value: settings.briefEnabled,
            onChanged: (v) =>
                ref.read(briefSettingsServiceProvider).setBriefEnabled(v),
          ),
          const Divider(),

          // Brief time
          ListTile(
            key: const ValueKey('brief-time'),
            title: Text(l.briefTime),
            subtitle: Text(l.briefTimeSub),
            trailing: TextButton(
              onPressed: _pickTime,
              child: Text(timeString),
            ),
          ),
          const Divider(),

          // TTS rate
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.spaceM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.briefTtsRate, style: theme.textTheme.titleSmall),
                SizedBox(height: Tokens.spaceXs),
                Text(
                  l.briefTtsRateSub,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: Tokens.spaceS),
                Row(
                  children: [
                    Text(l.briefTtsSlow),
                    Expanded(
                      child: Slider(
                        key: const ValueKey('brief-tts-slider'),
                        value: _rate,
                        min: ttsRateMin,
                        max: ttsRateMax,
                        divisions: 10,
                        label: '${_rate.toStringAsFixed(1)}×',
                        onChanged: (v) {
                          setState(() {
                            _rate = v;
                          });
                        },
                        onChangeEnd: (v) {
                          ref.read(briefSettingsServiceProvider).setTtsRate(v);
                        },
                      ),
                    ),
                    Text(l.briefTtsFast),
                  ],
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _testTts,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l.briefTtsTest),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // AI consent
          if (premium) ...[
            Padding(
              padding: EdgeInsets.all(Tokens.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.briefAiConsent, style: theme.textTheme.titleSmall),
                  SizedBox(height: Tokens.spaceXs),
                  Text(
                    l.briefAiConsentSub,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: Tokens.spaceM),
                  SegmentedButton<BriefConsent>(
                    key: const ValueKey('brief-consent'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: BriefConsent.ask,
                        label: Text(l.aiConsentAsk),
                      ),
                      ButtonSegment(
                        value: BriefConsent.always,
                        label: Text(l.aiAlways),
                      ),
                      ButtonSegment(
                        value: BriefConsent.never,
                        label: Text(l.aiNever),
                      ),
                    ],
                    selected: {settings.briefConsent},
                    onSelectionChanged: (s) => ref
                        .read(briefSettingsServiceProvider)
                        .setBriefConsent(s.first),
                  ),
                  if (aiAvailable) ...[
                    SizedBox(height: Tokens.spaceS),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: Tokens.iconS,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: Tokens.spaceXs),
                        Text(
                          l.briefAiReady,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: EdgeInsets.all(Tokens.spaceM),
              child: _PremiumUpgradeCard(
                title: l.briefPremiumTitle,
                body: l.briefPremiumBody,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal premium upgrade card for brief settings.
class _PremiumUpgradeCard extends StatelessWidget {
  const _PremiumUpgradeCard({required this.title, required this.body});

  final String title;
  final String body;

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
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Tokens.spaceS),
            Text(
              body,
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
