import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/capture_entry.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Tokens.spaceS),
            child: FilledButton.tonalIcon(
              key: const ValueKey('vault-scan'),
              onPressed: () => startScan(context),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan'),
            ),
          ),
          IconButton(
            key: const ValueKey('vault-import'),
            tooltip: 'Import from files',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => importFiles(context),
          ),
          IconButton(
            key: const ValueKey('vault-trash'),
            tooltip: 'Trash',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => context.push('/vault/trash'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64 + 48),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.spaceM,
                  0,
                  Tokens.spaceM,
                  Tokens.spaceS,
                ),
                child: SearchBar(
                  key: const ValueKey('vault-search'),
                  controller: _search,
                  hintText: 'Search documents…',
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
                  ],
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
        error: (e, _) => const EmptyState(
          emoji: '⚠️',
          title: "The Vault isn't available",
          message: 'Local data could not be opened on this device.',
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

    return ListView(
      key: const ValueKey('vault-home'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        const VaultSectionTitle('People'),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceM),
            children: [
              for (final p in persons)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.spaceS),
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
                label: const Text('Add'),
                onPressed: () => showPersonSheet(context),
              ),
            ],
          ),
        ),
        if (expiring.isNotEmpty) ...[
          VaultSectionTitle('⏰ Expiring soon (${expiring.length})'),
          SizedBox(
            height: 92,
            child: ListView(
              key: const ValueKey('expiring-strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceM),
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
          'Folders',
          trailing: TextButton.icon(
            key: const ValueKey('add-folder'),
            onPressed: () => showFolderSheet(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New folder'),
          ),
        ),
        for (final f in folders)
          ListTile(
            key: ValueKey('folder-${f.id}'),
            leading: Text(f.icon, style: const TextStyle(fontSize: 24)),
            title: Text(f.name),
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
            title: const Text('Unfiled'),
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

String _docCount(int n) => n == 1 ? '1 doc' : '$n docs';

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
      padding: const EdgeInsets.only(right: Tokens.spaceS),
      child: InkWell(
        key: ValueKey('expiring-${item.document.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/doc/${item.document.id}'),
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(Tokens.spaceS),
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
                  const SizedBox(width: 4),
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
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const EmptyState(
        emoji: '⚠️',
        title: "Search isn't available",
        message: 'Please try again.',
      ),
      data: (hits) => hits.isEmpty
          ? const EmptyState(
              emoji: '🔍',
              title: 'No matches',
              message:
                  'Try a title, an issuer like K-Electric, a word from the '
                  'document, or a tag.',
            )
          : ListView(
              key: const ValueKey('vault-search-results'),
              padding: const EdgeInsets.only(bottom: 120),
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
        padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceM),
        children: [
          _MenuChip<String?>(
            key: const ValueKey('filter-person'),
            label: person == null ? 'Person' : person.name,
            selected: person != null,
            options: [
              (null, 'Anyone'),
              for (final p in persons) (p.id, '${p.avatar ?? '👤'} ${p.name}'),
            ],
            onSelected: (v) => onChanged(copy(personId: v)),
          ),
          _MenuChip<String?>(
            key: const ValueKey('filter-type'),
            label: filters.docType == null
                ? 'Type'
                : typeName(filters.docType!),
            selected: filters.docType != null,
            options: [
              (null, 'Any type'),
              for (final t in docTypes) (t, '${docTypeIcon(t)} ${typeName(t)}'),
            ],
            onSelected: (v) => onChanged(copy(docType: v)),
          ),
          _MenuChip<AddedWithin>(
            key: const ValueKey('filter-added'),
            label: switch (filters.added) {
              AddedWithin.any => 'Added',
              AddedWithin.last30Days => 'Last 30 days',
              AddedWithin.thisYear => 'This year',
            },
            selected: filters.added != AddedWithin.any,
            options: const [
              (AddedWithin.any, 'Any time'),
              (AddedWithin.last30Days, 'Last 30 days'),
              (AddedWithin.thisYear, 'This year'),
            ],
            onSelected: (v) => onChanged(copy(added: v)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: Tokens.spaceS),
            child: FilterChip(
              key: const ValueKey('filter-expiring'),
              label: const Text('Expiring soon'),
              selected: filters.expiringSoon,
              onSelected: (v) => onChanged(copy(expiringSoon: v)),
            ),
          ),
          if (showClear)
            ActionChip(
              key: const ValueKey('filter-clear'),
              avatar: const Icon(Icons.close, size: 18),
              label: const Text('Clear'),
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
      padding: const EdgeInsets.only(right: Tokens.spaceS),
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
