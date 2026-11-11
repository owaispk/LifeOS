// Settings → Security → Share history (PBI-028a AC5): every share, kept
// only on this phone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/format.dart';
import '../../shared/widgets/empty_state.dart';
import 'data/share_service.dart' show idsOf;
import 'share_providers.dart';
import 'vault_providers.dart';

class ShareHistoryScreen extends ConsumerWidget {
  const ShareHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final events = ref.watch(shareHistoryProvider).value;
    final docs = ref.watch(documentsProvider).value ?? const <Document>[];
    final now = ref.watch(nowProvider)();
    final titles = {for (final d in docs) d.id: d.title};

    return Scaffold(
      appBar: AppBar(title: Text(l.shHistory)),
      body: events == null
          ? const Center(child: CircularProgressIndicator())
          : events.isEmpty
          ? EmptyState(
              emoji: '📤',
              title: l.shHistoryEmptyTitle,
              message: l.shHistoryEmptyMessage,
            )
          : ListView(
              key: const ValueKey('share-history'),
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              children: [
                for (final e in events)
                  _EventTile(event: e, titles: titles, now: now),
              ],
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.titles,
    required this.now,
  });

  final ShareEvent event;
  final Map<String, String> titles;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = [
      for (final id in idsOf(event.documentIds)) titles[id] ?? l.shDeletedDoc,
    ];
    final at = DateTime.fromMillisecondsSinceEpoch(event.sharedAt);
    final title = event.bundleTitle ?? names.join(', ');
    return ListTile(
      key: ValueKey('share-event-${event.id}'),
      minTileHeight: Tokens.rowTwoLine,
      leading: Icon(
        event.watermarked ? Icons.branding_watermark_outlined : Icons.ios_share,
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          '${relativeDay(at, now)} ${formatTime(at)}',
          if (event.recipient != null) l.shTo(event.recipient!),
          if (event.purpose != null) event.purpose!,
          if (event.watermarked) l.shWatermarked,
          if (event.bundleTitle != null) names.join(', '),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
