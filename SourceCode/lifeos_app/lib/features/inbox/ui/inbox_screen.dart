// Inbox screen: list of pending captures (PBI-026).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../domain/capture_model.dart';
import '../inbox_providers.dart';
import 'capture_fab.dart';
import 'classify_modal.dart';

/// The Inbox screen showing all pending captures.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(pendingCapturesProvider);
    final l = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.inboxTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: capturesAsync.when(
        data: (captures) {
          if (captures.isEmpty) {
            return _EmptyInbox();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingCapturesProvider),
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              itemCount: captures.length,
              itemBuilder: (context, index) {
                final capture = captures[index];
                return _CaptureTile(
                  capture: capture,
                  onTap: () => _showClassifyModal(context, capture),
                  onDismiss: () => _dismissCapture(context, ref, capture),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l.inboxError,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
      floatingActionButton: const CaptureFab(),
    );
  }

  void _showClassifyModal(BuildContext context, Capture capture) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => ClassifyModal(capture: capture),
    );
  }

  Future<void> _dismissCapture(
    BuildContext context,
    WidgetRef ref,
    Capture capture,
  ) async {
    final service = ref.read(inboxServiceProvider);
    final l = context.l10n;
    
    final deleted = await service.dismiss(capture.id);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.inboxDismissed),
          action: SnackBarAction(
            label: l.cpUndo,
            onPressed: () async {
              await service.undoDismiss(deleted.id);
            },
          ),
        ),
      );
    }
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(Tokens.spaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: Tokens.spaceM),
            Text(
              l.inboxEmptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Tokens.spaceS),
            Text(
              l.inboxEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.capture,
    required this.onTap,
    required this.onDismiss,
  });

  final Capture capture;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    return Dismissible(
      key: ValueKey(capture.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: Tokens.spaceM),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onError,
        ),
      ),
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        leading: _CaptureIcon(type: capture.type),
        title: Text(
          capture.displayText.isNotEmpty
              ? capture.displayText
              : l.inboxUntitled,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          relativeTime(capture.capturedAt, DateTime.now()),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon({required this.type});

  final CaptureType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (type) {
      CaptureType.text => (Icons.text_snippet_outlined, theme.colorScheme.primary),
      CaptureType.voice => (Icons.mic_outlined, theme.colorScheme.secondary),
      CaptureType.photo => (Icons.photo_outlined, theme.colorScheme.tertiary),
      CaptureType.file => (Icons.attach_file_outlined, theme.colorScheme.outline),
    };

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Relative time display (e.g., "2 min ago", "1 hour ago").
String relativeTime(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return relativeDay(time, now);
}
