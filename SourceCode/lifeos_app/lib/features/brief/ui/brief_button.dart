// "Get your brief" button for Home dashboard (PBI-039a).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../brief_providers.dart';
import 'brief_screen.dart';

/// Compact button to open the brief screen from Home.
class BriefButton extends ConsumerWidget {
  const BriefButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(briefDataProvider);

    return Card(
      key: const ValueKey('home-brief'),
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Text('🎙️', style: TextStyle(fontSize: 22)),
        title: Text(
          l.briefButtonTitle,
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
        subtitle: data.when(
          loading: () => null,
          error: (_, _) => null,
          data: (d) => Text(
            l.briefButtonSubtitle(d.lifeScore, d.taskCount),
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onPrimaryContainer,
        ),
        onTap: () => context.push(briefRoute),
      ),
    );
  }
}

/// Larger card variant for prominent placement.
class BriefCard extends ConsumerWidget {
  const BriefCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(briefDataProvider);

    return Card(
      key: const ValueKey('brief-card-home'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(briefRoute),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primary.withValues(alpha: 0.3),
              ],
            ),
          ),
          padding: EdgeInsets.all(Tokens.spaceM),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(Tokens.spaceS),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(Tokens.radiusM),
                ),
                child: const Text('🎙️', style: TextStyle(fontSize: 28)),
              ),
              SizedBox(width: Tokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.briefButtonTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: Tokens.spaceXs),
                    data.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (d) => Text(
                        _buildPreview(l, d),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                color: theme.colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPreview(AppLocalizations l, BriefData data) {
    if (data.isClearDay) return l.briefPreviewClear;
    if (data.hasUrgentItems) return l.briefPreviewUrgent;
    return l.briefPreviewNormal(data.taskCount);
  }
}

/// Mini floating action button variant.
class BriefFab extends StatelessWidget {
  const BriefFab({super.key, this.mini = false});

  final bool mini;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return FloatingActionButton(
      mini: mini,
      heroTag: 'brief-fab',
      tooltip: l.briefButtonTitle,
      onPressed: () => context.push(briefRoute),
      child: const Icon(Icons.record_voice_over),
    );
  }
}
