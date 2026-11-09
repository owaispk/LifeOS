import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/db/app_database.dart';
import '../vault_providers.dart';

const personEmojis = ['🙂', '👩', '👨', '👧', '👦', '👵', '👴', '🧑'];
const _folderIcons = ['📁', '✈️', '💼', '🏦', '🐾', '🎮', '🍽️', '🧳'];
Map<String, String> _relations(AppLocalizations l) => {
  'spouse': l.vtRelationSpouse,
  'child': l.vtRelationChild,
  'parent': l.vtRelationParent,
  'other': l.vtRelationOther,
};

/// Add (when [person] is null) or edit a person profile.
Future<void> showPersonSheet(BuildContext context, {Person? person}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => _PersonSheet(person: person),
  );
}

class _PersonSheet extends ConsumerStatefulWidget {
  const _PersonSheet({this.person});
  final Person? person;

  @override
  ConsumerState<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<_PersonSheet> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late String _relation = widget.person?.relation ?? 'child';
  late String _avatar = widget.person?.avatar ?? '🙂';

  bool get _isSelf => widget.person?.relation == 'self';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final service = ref.read(vaultServiceProvider);
    final p = widget.person;
    if (p == null) {
      await service.addPerson(
        name: _name.text,
        relation: _relation,
        avatar: _avatar,
      );
    } else {
      await service.updatePerson(
        p.id,
        name: _name.text,
        relation: _relation,
        avatar: _avatar,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _SheetFrame(
      title: widget.person == null ? l.vtAddPerson : l.vtEditPerson,
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        TextField(
          key: const ValueKey('person-name'),
          controller: _name,
          autofocus: widget.person == null,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.name,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (!_isSelf) ...[
          SizedBox(height: Tokens.spaceM),
          Wrap(
            spacing: Tokens.spaceS,
            children: [
              for (final e in _relations(l).entries)
                ChoiceChip(
                  key: ValueKey('relation-${e.key}'),
                  label: Text(e.value),
                  selected: _relation == e.key,
                  onSelected: (_) => setState(() => _relation = e.key),
                ),
            ],
          ),
        ],
        SizedBox(height: Tokens.spaceM),
        EmojiPicker(
          options: personEmojis,
          selected: _avatar,
          onSelected: (e) => setState(() => _avatar = e),
        ),
      ],
    );
  }
}

/// Add (when [folder] is null) or rename a custom folder.
Future<void> showFolderSheet(BuildContext context, {Folder? folder}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // above the tab bar and its ➕ button
    isScrollControlled: true,
    builder: (context) => _FolderSheet(folder: folder),
  );
}

class _FolderSheet extends ConsumerStatefulWidget {
  const _FolderSheet({this.folder});
  final Folder? folder;

  @override
  ConsumerState<_FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends ConsumerState<_FolderSheet> {
  late final _name = TextEditingController(text: widget.folder?.name ?? '');
  late String _icon = widget.folder?.icon ?? '📁';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final service = ref.read(vaultServiceProvider);
    final f = widget.folder;
    if (f == null) {
      await service.addFolder(name: _name.text, icon: _icon);
    } else {
      await service.updateFolder(f.id, name: _name.text, icon: _icon);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _SheetFrame(
      title: widget.folder == null ? l.vtNewFolder : l.vtRenameFolder,
      onSave: _name.text.trim().isEmpty ? null : _save,
      children: [
        TextField(
          key: const ValueKey('folder-name'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.vtFolderName,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: Tokens.spaceM),
        EmojiPicker(
          options: _folderIcons,
          selected: _icon,
          onSelected: (e) => setState(() => _icon = e),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.onSave,
    required this.children,
  });

  final String title;
  final VoidCallback? onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.spaceM,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: Tokens.spaceM),
            ...children,
            SizedBox(height: Tokens.spaceM),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const ValueKey('sheet-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(96, Tokens.minTouchTarget),
                ),
                onPressed: onSave,
                child: Text(context.l10n.vtSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of emoji chips (person avatars, folder icons, My Profile).
class EmojiPicker extends StatelessWidget {
  const EmojiPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Tokens.spaceXs,
      children: [
        for (final e in options)
          ChoiceChip(
            key: ValueKey('emoji-$e'),
            label: Text(e, style: const TextStyle(fontSize: 20)),
            selected: selected == e,
            showCheckmark: false,
            onSelected: (_) => onSelected(e),
          ),
      ],
    );
  }
}
