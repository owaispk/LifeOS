import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/now_provider.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/empty_state.dart';
import '../capture/capture_entry.dart';
import 'domain/vault_rules.dart';
import 'ui/document_sheet.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docs = ref.watch(documentsProvider);
    final query = _search.text.trim();

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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
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
        ),
      ),
      body: docs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const EmptyState(
          emoji: '⚠️',
          title: "The Vault isn't available",
          message: 'Local data could not be opened on this device.',
        ),
        data: (list) => query.isEmpty
            ? _VaultHome(documents: list)
            : _SearchResults(results: searchDocuments(list, query)),
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
        onTap: () => showDocumentSheet(context, item.document.id),
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

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results});

  final List<Document> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(
        emoji: '🔍',
        title: 'No matches',
        message: 'Try a title, an issuer like K-Electric, or a tag.',
      );
    }
    return ListView(
      key: const ValueKey('vault-search-results'),
      padding: const EdgeInsets.only(bottom: 120),
      children: [for (final d in results) DocumentTile(document: d)],
    );
  }
}
