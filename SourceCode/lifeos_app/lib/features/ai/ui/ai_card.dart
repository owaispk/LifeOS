import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../capture/capture_providers.dart';
import '../../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../ai_providers.dart';

/// The one place the confirm screen says anything about cloud AI
/// (PBI-027a): the consent question, the free-tier teaser, a spinner
/// while a call is out, or the provider's error. Inline and dismissible
/// — never a notification (AC4, PBI-023).
class AiCard extends ConsumerWidget {
  const AiCard({super.key, required this.entryId});

  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      captureSessionProvider.select((s) => s.byId(entryId)),
    );
    if (entry == null) return const SizedBox.shrink();
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.read(captureSessionProvider.notifier);

    if (entry.aiBusy) {
      return _Shell(
        key: const ValueKey('ai-busy'),
        child: Row(
          children: [
            SizedBox.square(
              dimension: Tokens.spaceL,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: Tokens.spaceM),
            Expanded(child: Text(l.aiReading)),
          ],
        ),
      );
    }

    final error = entry.aiError;
    if (error != null) {
      return _Shell(
        key: const ValueKey('ai-error'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.aiFailedPrefix(error), style: theme.textTheme.bodySmall),
            SizedBox(height: Tokens.spaceXs),
            Text(l.aiKeptLocal, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    return switch (entry.aiGate) {
      // Ask once; the answer can be remembered (AC7).
      AiGate.ask => _Shell(
        key: const ValueKey('ai-consent'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.aiConsentTitle, style: theme.textTheme.titleSmall),
            SizedBox(height: Tokens.spaceXs),
            // The destination is named accurately for the mode in use
            // (PBI-027b AC6): LifeOS as a pass-through, or the user's
            // own provider.
            Text(
              ref.watch(aiSettingsProvider).value?.mode == AiMode.managed
                  ? l.aiConsentBodyManaged
                  : l.aiConsentBody,
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: Tokens.spaceS),
            Wrap(
              spacing: Tokens.spaceS,
              children: [
                FilledButton(
                  key: const ValueKey('ai-consent-once'),
                  onPressed: () => session.runAi(entryId),
                  child: Text(l.aiJustOnce),
                ),
                TextButton(
                  key: const ValueKey('ai-consent-always'),
                  onPressed: () =>
                      session.runAi(entryId, remember: AiConsent.always),
                  child: Text(l.aiAlways),
                ),
                TextButton(
                  key: const ValueKey('ai-consent-never'),
                  onPressed: () async {
                    await ref
                        .read(aiSettingsServiceProvider)
                        .setConsent(AiConsent.never);
                    session.dismissAiTeaser(entryId);
                  },
                  child: Text(l.aiNever),
                ),
              ],
            ),
          ],
        ),
      ),
      // Free tier: the pitch, once, dismissible for good (AC4).
      AiGate.notPremium when !entry.aiDismissed => _Shell(
        key: const ValueKey('ai-teaser'),
        child: Row(
          children: [
            Expanded(
              child: Text(l.aiTeaser, style: theme.textTheme.bodySmall),
            ),
            TextButton(
              key: const ValueKey('ai-teaser-see'),
              onPressed: () => context.go(premiumRoute),
              child: Text(l.aiUpgrade),
            ),
            IconButton(
              key: const ValueKey('ai-teaser-dismiss'),
              tooltip: l.aiDismiss,
              icon: const Icon(Icons.close),
              onPressed: () => session.dismissAiTeaser(entryId),
            ),
          ],
        ),
      ),
      // Confident, no text, not configured, refused, already sent:
      // nothing to say.
      _ => const SizedBox.shrink(),
    };
  }
}

class _Shell extends StatelessWidget {
  const _Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.symmetric(vertical: Tokens.spaceS),
    child: Padding(padding: EdgeInsets.all(Tokens.spaceM), child: child),
  );
}

/// The "AI-read" chip shown beside a field the provider filled (AC2).
class AiBadge extends StatelessWidget {
  const AiBadge({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: Tokens.spaceS),
    child: Chip(
      key: const ValueKey('ai-badge'),
      visualDensity: VisualDensity.compact,
      avatar: const Text('✨'),
      label: Text(context.l10n.aiReadBadge),
    ),
  );
}
