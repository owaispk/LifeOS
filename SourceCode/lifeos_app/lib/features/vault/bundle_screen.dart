// "Share as one PDF" and share packs (PBI-028a).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/section_header.dart';
import 'data/share_service.dart' show idsOf;
import 'domain/vault_rules.dart';
import 'share_providers.dart';
import 'ui/share_flow.dart';
import 'vault_providers.dart';

/// Where the bundle screen lives (above the tabs).
const bundleRoute = '/bundle';

/// The bundle screen for [ids], or for the share pack [pack], or for the
/// preset "Job Application Pack" ([preset] = 'job').
String bundleLocation({List<String>? ids, String? pack, String? preset}) => Uri(
  path: bundleRoute,
  queryParameters: {
    if (ids != null) 'ids': ids.join(','),
    'pack': ?pack,
    'preset': ?preset,
  },
).toString();

class BundleScreen extends ConsumerStatefulWidget {
  const BundleScreen({super.key, this.ids = const [], this.pack, this.preset});

  final List<String> ids;
  final String? pack;
  final String? preset;

  @override
  ConsumerState<BundleScreen> createState() => _BundleScreenState();
}

class _BundleScreenState extends ConsumerState<BundleScreen> {
  final _title = TextEditingController();
  final _recipient = TextEditingController();
  final _purpose = TextEditingController();
  List<String>? _ids;
  int _missing = 0;
  bool _watermark = false;
  bool _tried = false;
  bool _saveToVault = false;
  String? _folderId;
  String? _packId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(shareServiceProvider);
    var ids = widget.ids;
    if (widget.pack != null) {
      final pack = await service.template(widget.pack!);
      if (!mounted) return;
      if (pack != null) {
        _packId = pack.id;
        _title.text = pack.name;
        ids = idsOf(pack.documentIds);
      }
    } else if (widget.preset == 'job') {
      _title.text = l10nNow.shJobPack;
      ids = await service.jobPackSuggestion();
    }
    if (!mounted) return;
    // A pack follows renewals to today's documents (AC4).
    final docs = await service.resolve(ids);
    if (!mounted) return;
    setState(() {
      _ids = [for (final d in docs) d.id];
      _missing = ids.length - docs.length;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _recipient.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _addDocuments(List<Document> all) async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DocumentPicker(all: all, selected: _ids!),
    );
    if (picked != null) setState(() => _ids = picked);
  }

  Future<void> _savePack() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final name = _title.text.trim().isEmpty ? l.shJobPack : _title.text.trim();
    final saved = await ref
        .read(shareServiceProvider)
        .saveTemplate(name, _ids!, id: _packId);
    _packId = saved.id;
    messenger.showSnackBar(SnackBar(content: Text(l.shPackSaved)));
  }

  Future<void> _share() async {
    if (_ids!.isEmpty) return;
    if (_watermark && _recipient.text.trim().isEmpty) {
      setState(() => _tried = true);
      return;
    }
    setState(() => _busy = true);
    final ok = await sharePdf(
      context,
      ref,
      documentIds: _ids!,
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      watermark: _watermark
          ? (recipient: _recipient.text.trim(), purpose: _purpose.text.trim())
          : null,
      saveToVault: _saveToVault,
      folderId: _folderId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(documentsProvider).value ?? const <Document>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final byId = {for (final d in all) d.id: d};
    final ids = _ids;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shShareAsPdf),
        actions: [
          IconButton(
            key: const ValueKey('bundle-save-pack'),
            tooltip: l.shSavePack,
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: ids == null || ids.isEmpty ? null : _savePack,
          ),
        ],
      ),
      body: ids == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const ValueKey('bundle-list'),
              padding: EdgeInsets.only(bottom: Tokens.listEnd),
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    Tokens.gutter,
                    Tokens.spaceM,
                    Tokens.gutter,
                    0,
                  ),
                  child: TextField(
                    key: const ValueKey('bundle-title'),
                    controller: _title,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l.shPackTitle,
                      hintText: l.shPackTitleHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                SectionHeader(l.shDocuments),
                if (_missing > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: Text(
                      l.shMissingDocs(_missing),
                      key: const ValueKey('bundle-missing'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (ids.length > 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: Text(
                      l.shReorderHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (from, to) =>
                      setState(() => ids.insert(to, ids.removeAt(from))),
                  children: [
                    for (var i = 0; i < ids.length; i++)
                      ListTile(
                        key: ValueKey('bundle-doc-${ids[i]}'),
                        minTileHeight: Tokens.rowOneLine,
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_indicator),
                        ),
                        title: Text(
                          byId[ids[i]]?.title ?? l.shDeletedDoc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: byId[ids[i]] == null
                            ? null
                            : Text(docTypeLabel(byId[ids[i]]!.docType)),
                        trailing: IconButton(
                          key: ValueKey('bundle-remove-${ids[i]}'),
                          tooltip: l.shRemove,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => ids.removeAt(i)),
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.spaceS),
                    child: TextButton.icon(
                      key: const ValueKey('bundle-add'),
                      onPressed: () => _addDocuments(
                        all.where((d) => d.archivedAt == null).toList(),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(l.shAddDocuments),
                    ),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('bundle-watermark'),
                  title: Text(l.shWatermarkTitle),
                  subtitle: Text(l.shShareWatermarkSub),
                  value: _watermark,
                  onChanged: (v) => setState(() => _watermark = v),
                ),
                if (_watermark)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: WatermarkFields(
                      recipient: _recipient,
                      purpose: _purpose,
                      showError: _tried,
                    ),
                  ),
                CheckboxListTile(
                  key: const ValueKey('bundle-save-vault'),
                  title: Text(l.shSaveToVault),
                  value: _saveToVault,
                  onChanged: (v) => setState(() => _saveToVault = v ?? false),
                ),
                if (_saveToVault)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Tokens.gutter),
                    child: DropdownButtonFormField<String?>(
                      key: const ValueKey('bundle-folder'),
                      initialValue: _folderId,
                      decoration: InputDecoration(
                        labelText: l.shSaveFolder,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l.vtUnfiled)),
                        for (final f in folders)
                          DropdownMenuItem(
                            value: f.id,
                            child: Text('${f.icon} ${folderLabel(f)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _folderId = v),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.gutter),
          child: FilledButton.icon(
            key: const ValueKey('bundle-share'),
            onPressed: ids == null || ids.isEmpty || _busy ? null : _share,
            icon: const Icon(Icons.ios_share),
            label: Text(
              ids != null && ids.isEmpty ? l.shNoDocuments : l.shShare,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick which documents go in the bundle (keeps the existing order).
class _DocumentPicker extends StatefulWidget {
  const _DocumentPicker({required this.all, required this.selected});
  final List<Document> all;
  final List<String> selected;

  @override
  State<_DocumentPicker> createState() => _DocumentPickerState();
}

class _DocumentPickerState extends State<_DocumentPicker> {
  late final List<String> _picked = [...widget.selected];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final docs = sortDocuments(widget.all);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => Column(
        children: [
          ListTile(
            title: Text(
              l.shPickDocuments,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: FilledButton(
              key: const ValueKey('picker-done'),
              onPressed: () => Navigator.pop(context, _picked),
              child: Text(l.shDone),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                for (final d in docs)
                  CheckboxListTile(
                    key: ValueKey('pick-${d.id}'),
                    value: _picked.contains(d.id),
                    title: Text(
                      d.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(docTypeLabel(d.docType)),
                    onChanged: (on) => setState(() {
                      on == true ? _picked.add(d.id) : _picked.remove(d.id);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vault → Share packs: the preset "Job Application Pack" and the user's
/// own packs.
class SharePacksScreen extends ConsumerWidget {
  const SharePacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final packs =
        ref.watch(bundleTemplatesProvider).value ?? const <BundleTemplate>[];
    // Once the preset is saved (edited), the saved one stands in for it.
    final hasJob = packs.any((p) => p.name == l.shJobPack);
    return Scaffold(
      appBar: AppBar(title: Text(l.shPacks)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('pack-new'),
        heroTag: null,
        onPressed: () => context.push(bundleLocation(ids: const [])),
        icon: const Icon(Icons.add),
        label: Text(l.shNewPack),
      ),
      body: ListView(
        key: const ValueKey('packs-list'),
        padding: EdgeInsets.only(bottom: Tokens.listEnd),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Tokens.gutter,
              Tokens.spaceM,
              Tokens.gutter,
              Tokens.spaceS,
            ),
            child: Text(
              l.shPacksSub,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (!hasJob)
            ListTile(
              key: const ValueKey('pack-job'),
              minTileHeight: Tokens.rowTwoLine,
              leading: const Icon(Icons.work_outline),
              title: Text(l.shJobPack),
              subtitle: Text(l.shJobPackSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(bundleLocation(preset: 'job')),
            ),
          for (final p in packs)
            ListTile(
              key: ValueKey('pack-${p.id}'),
              minTileHeight: Tokens.rowTwoLine,
              leading: const Icon(Icons.folder_copy_outlined),
              title: Text(p.name),
              subtitle: Text(l.shPackCount(idsOf(p.documentIds).length)),
              trailing: IconButton(
                key: ValueKey('pack-delete-${p.id}'),
                tooltip: l.shDeletePack,
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(shareServiceProvider).deleteTemplate(p.id),
              ),
              onTap: () => context.push(bundleLocation(pack: p.id)),
            ),
        ],
      ),
    );
  }
}
