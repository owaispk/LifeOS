import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/capture_entry.dart';
import '../premium/premium_providers.dart';
import '../premium/ui/upgrade_prompt.dart' show premiumRoute;
import '../capture/ocr/doc_classifier.dart' show docTypes;
import '../capture/ocr/field_extractor.dart' show typeName;
import 'data/search_service.dart';
import 'domain/vault_rules.dart';
import 'ui/document_tile.dart';
import 'ui/vault_sheets.dart';
import 'vault_providers.dart';

/// 3.1 Vault Home (UI flow §3.1).
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  SearchFilters _filters = noFilters;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);
    final query = _search.text.trim();
    final searching = query.isNotEmpty || hasFilters(_filters);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.vtVaultTitle),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: Tokens.spaceS),
            child: FilledButton.tonalIcon(
              key: const ValueKey('vault-scan'),
              onPressed: () => startScan(context),
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(l.vtScan),
            ),
          ),
          IconButton(
            key: const ValueKey('vault-import'),
            tooltip: l.vtImportFiles,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => importFiles(context),
          ),
          IconButton(
            key: const ValueKey('vault-trash'),
            tooltip: l.trash,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push('/vault/trash'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64 + 48),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Tokens.gutter,
                  0,
                  Tokens.gutter,
                  Tokens.spaceS,
                ),
                // A text field styled as a search pill: the whole pill is
                // the tap target (≥ 48 dp), not just the text line
                // (PBI-031 AC3).
                child: TextField(
                  key: const ValueKey('vault-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.vtSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.vtClearSearch,
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHigh,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: Tokens.spaceM,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radius * 2),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _FilterBar(
                filters: _filters,
                onChanged: (f) => setState(() => _filters = f),
                // AC6: clearing everything returns to Vault Home.
                onClear: () => setState(() {
                  _filters = noFilters;
                  _search.clear();
                }),
                showClear: searching,
              ),
            ],
          ),
        ),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          emoji: '⚠️',
          title: l.vtUnavailableTitle,
          message: l.vtUnavailableMessage,
        ),
        data: (list) => searching
            ? _SearchResults(query: query, filters: _filters)
            : _VaultHome(documents: list),
      ),
    );
  }
}

class _VaultHome extends ConsumerWidget {
  const _VaultHome({required this.documents});

  final List<Document> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final counts = folderCounts(documents);
    final expiring = expiringSoon(documents, now);
    final unfiled = counts[null] ?? 0;
    final l = context.l10n;

    // How much room is left on the free plan, once it is close (PBI-029
    // AC8). One quiet line in the Vault, never a notification.
    final left = ref.watch(documentsLeftProvider);

    return ListView(
      key: const ValueKey('vault-home'),
      padding: EdgeInsets.only(bottom: Tokens.listEnd),
      children: [
        if (left != null)
          ListTile(
            key: const ValueKey('vault-docs-left'),
            dense: true,
            leading: const Text('⭐'),
            title: Text(l.pmDocsLeft(left)),
            trailing: TextButton(
              key: const ValueKey('vault-see-premium'),
              onPressed: () => context.go(premiumRoute),
              child: Text(l.pmSeePremium),
            ),
          ),
        VaultSectionTitle(l.vtPeople),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
            children: [
              for (final p in persons)
                Padding(
                  padding: EdgeInsets.only(right: Tokens.spaceS),
                  child: ActionChip(
                    key: ValueKey('person-${p.id}'),
                    avatar: Text(p.avatar ?? '👤'),
                    label: Text(p.name),
                    onPressed: () => context.go('/vault/person/${p.id}'),
                  ),
                ),
              ActionChip(
                key: const ValueKey('add-person'),
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l.vtAdd),
                onPressed: () => showPersonSheet(context),
              ),
            ],
          ),
        ),
        if (expiring.isNotEmpty) ...[
          VaultSectionTitle(
            l.vtExpiringSoonCount('${expiring.length}'),
            trailing: TextButton(
              key: const ValueKey('expiring-see-all'),
              onPressed: () => context.go('/vault/expiring'),
              child: Text(l.vtSeeAll),
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView(
              key: const ValueKey('expiring-strip'),
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
              children: [
                for (final e in expiring)
                  _ExpiryCard(
                    item: e,
                    person: persons
                        .where((p) => p.id == e.document.personId)
                        .firstOrNull,
                  ),
              ],
            ),
          ),
        ],
        VaultSectionTitle(
          l.vtFolders,
          trailing: TextButton.icon(
            key: const ValueKey('add-folder'),
            onPressed: () => showFolderSheet(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(l.vtNewFolder),
          ),
        ),
        for (final f in folders)
          ListTile(
            key: ValueKey('folder-${f.id}'),
            leading: Text(f.icon, style: const TextStyle(fontSize: 24)),
            title: Text(folderLabel(f)),
            trailing: Text(
              _docCount(counts[f.id] ?? 0),
              key: ValueKey('folder-count-${f.id}'),
            ),
            onTap: () => context.go('/vault/folder/${f.id}'),
          ),
        if (unfiled > 0)
          ListTile(
            key: const ValueKey('folder-unfiled'),
            leading: const Text('📥', style: TextStyle(fontSize: 24)),
            title: Text(l.vtUnfiled),
            trailing: Text(
              _docCount(unfiled),
              key: const ValueKey('folder-count-unfiled'),
            ),
            onTap: () => context.go('/vault/unfiled'),
          ),
      ],
    );
  }
}

String _docCount(int n) => l10nNow.vtDocCount(n);

class _ExpiryCard extends StatelessWidget {
  const _ExpiryCard({required this.item, required this.person});

  final ExpiringDoc item;
  final Person? person;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (Color accent, IconData icon) = switch (item.urgency) {
      ExpiryUrgency.critical => (scheme.error, Icons.error_outline),
      ExpiryUrgency.soon => (const Color(0xFFB26A00), Icons.schedule),
      ExpiryUrgency.later => (scheme.outline, Icons.event),
    };
    return Padding(
      padding: EdgeInsets.only(right: Tokens.spaceS),
      child: InkWell(
        key: ValueKey('expiring-${item.document.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/doc/${item.document.id}'),
        child: Container(
          width: 168,
          padding: EdgeInsets.all(Tokens.spaceS),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 4)),
            color: scheme.surfaceContainerHighest,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.document.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (person != null)
                Text(
                  person!.name,
                  maxLines: 1,
                  style: theme.textTheme.bodySmall,
                ),
              Row(
                children: [
                  Icon(icon, size: 14, color: accent),
                  SizedBox(width: Tokens.spaceXs),
                  Text(item.label, style: theme.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-text results for the query + filters (PBI-006).
final searchResultsProvider = FutureProvider.autoDispose
    .family<List<SearchHit>, (String, SearchFilters)>((ref, key) {
      // Re-run whenever documents change (edits, deletes, new scans).
      ref.watch(documentsProvider);
      return ref.watch(searchServiceProvider).search(key.$1, key.$2);
    });

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.filters});

  final String query;
  final SearchFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider((query, filters)));
    final l = context.l10n;
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        emoji: '⚠️',
        title: l.vtSearchUnavailable,
        message: l.vtTryAgain,
      ),
      data: (hits) => hits.isEmpty
          ? EmptyState(
              emoji: '🔍',
              title: l.vtNoMatches,
              message: l.vtNoMatchesHint,
            )
          : ListView(
              key: const ValueKey('vault-search-results'),
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              children: [
                for (final h in hits)
                  DocumentTile(document: h.document, snippet: h.snippet),
              ],
            ),
    );
  }
}

const _keep = Object();

/// Person · Type · Added · Expiring soon filter chips (PBI-006).
class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.filters,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final person = persons.where((p) => p.id == filters.personId).firstOrNull;
    final l = context.l10n;
    SearchFilters copy({
      Object? personId = _keep,
      Object? docType = _keep,
      AddedWithin? added,
      bool? expiringSoon,
    }) => (
      personId: identical(personId, _keep)
          ? filters.personId
          : personId as String?,
      docType: identical(docType, _keep) ? filters.docType : docType as String?,
      added: added ?? filters.added,
      expiringSoon: expiringSoon ?? filters.expiringSoon,
    );

    return SizedBox(
      height: 48,
      child: ListView(
        key: const ValueKey('vault-filters'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
        children: [
          _MenuChip<String?>(
            key: const ValueKey('filter-person'),
            label: person == null ? l.vtPerson : person.name,
            selected: person != null,
            options: [
              (null, l.vtAnyone),
              for (final p in persons) (p.id, '${p.avatar ?? '👤'} ${p.name}'),
            ],
            onSelected: (v) => onChanged(copy(personId: v)),
          ),
          _MenuChip<String?>(
            key: const ValueKey('filter-type'),
            label: filters.docType == null
                ? l.vtType
                : typeName(filters.docType!),
            selected: filters.docType != null,
            options: [
              (null, l.vtAnyType),
              for (final t in docTypes) (t, '${docTypeIcon(t)} ${typeName(t)}'),
            ],
            onSelected: (v) => onChanged(copy(docType: v)),
          ),
          _MenuChip<AddedWithin>(
            key: const ValueKey('filter-added'),
            label: switch (filters.added) {
              AddedWithin.any => l.vtAdded,
              AddedWithin.last30Days => l.vtLast30Days,
              AddedWithin.thisYear => l.vtThisYear,
            },
            selected: filters.added != AddedWithin.any,
            options: [
              (AddedWithin.any, l.vtAnyTime),
              (AddedWithin.last30Days, l.vtLast30Days),
              (AddedWithin.thisYear, l.vtThisYear),
            ],
            onSelected: (v) => onChanged(copy(added: v)),
          ),
          Padding(
            padding: EdgeInsets.only(right: Tokens.spaceS),
            child: FilterChip(
              key: const ValueKey('filter-expiring'),
              label: Text(l.vtExpiringSoon),
              selected: filters.expiringSoon,
              onSelected: (v) => onChanged(copy(expiringSoon: v)),
            ),
          ),
          if (showClear)
            ActionChip(
              key: const ValueKey('filter-clear'),
              avatar: const Icon(Icons.close, size: 18),
              label: Text(l.vtClear),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    super.key,
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: Tokens.spaceS),
      child: PopupMenuButton<int>(
        tooltip: label,
        onSelected: (i) => onSelected(options[i].$1),
        itemBuilder: (context) => [
          for (var i = 0; i < options.length; i++)
            PopupMenuItem(value: i, child: Text(options[i].$2)),
        ],
        child: Chip(
          label: Text(label),
          avatar: Icon(
            selected ? Icons.check : Icons.arrow_drop_down,
            size: 18,
          ),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
      ),
    );
  }
}
