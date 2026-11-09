import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/now_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../../../shared/format.dart';
import '../domain/vault_rules.dart';
import '../vault_providers.dart';
import 'document_pages.dart' show fileBytesProvider;

/// One document row: thumbnail · title · type chip · date · person · ★.
class DocumentTile extends ConsumerWidget {
  const DocumentTile({super.key, required this.document, this.snippet});

  final Document document;

  /// Search snippet with the match wrapped in « » (PBI-006).
  final String? snippet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final page = ref.watch(firstPagesProvider).value?[document.id];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final person = persons.where((p) => p.id == document.personId).firstOrNull;

    return ListTile(
      key: ValueKey('doc-${document.id}'),
      minTileHeight: Tokens.rowTwoLine,
      onTap: () => context.push('/doc/${document.id}'),
      leading: _Thumbnail(document: document, page: page),
      title: Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              docTypeLabel(document.docType),
              relativeDay(createdAt(document), now),
              if (person != null) '${person.avatar ?? '👤'} ${person.name}',
              if (document.archivedAt != null) context.l10n.vtArchived,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (snippet != null && snippet!.contains('«'))
            Text.rich(
              _highlight(snippet!, theme),
              key: ValueKey('snippet-${document.id}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: document.favorite
          ? Icon(
              Icons.star,
              color: theme.colorScheme.primary,
              semanticLabel: context.l10n.vtFavourite,
            )
          : null,
    );
  }
}

/// Renders «match» segments in bold.
TextSpan _highlight(String snippet, ThemeData theme) {
  final spans = <TextSpan>[];
  final parts = snippet.split(RegExp('[«»]'));
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    spans.add(
      TextSpan(
        text: parts[i],
        style: i.isOdd
            ? TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              )
            : null,
      ),
    );
  }
  return TextSpan(style: theme.textTheme.bodySmall, children: spans);
}

class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.document, required this.page});

  final Document document;
  final DocumentFile? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final f = page;
    final isImage = f?.mime.startsWith('image/') ?? false;
    final icon = Center(
      child: Text(
        docTypeIcon(document.docType),
        style: const TextStyle(fontSize: 24),
      ),
    );
    final Widget child;
    if (!kIsWeb && isImage && f?.localPath != null) {
      // Decrypted in memory (PBI-024); the type icon stands in meanwhile.
      child = ref
          .watch(fileBytesProvider(f!))
          .maybeWhen(
            data: (b) => Image.memory(b, fit: BoxFit.cover, cacheWidth: 96),
            orElse: () => icon,
          );
    } else {
      child = icon;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 56,
        color: scheme.surfaceContainerHighest,
        child: child,
      ),
    );
  }
}

/// Section title used across Vault screens.
class VaultSectionTitle extends StatelessWidget {
  const VaultSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        // Start/end (not left/right), so Urdu mirrors it exactly.
        padding: EdgeInsetsDirectional.fromSTEB(
          Tokens.gutter,
          Tokens.spaceL,
          Tokens.spaceS,
          Tokens.spaceXs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
