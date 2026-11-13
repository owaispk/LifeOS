// Quick text entry bottom sheet (PBI-026).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../inbox_providers.dart';

/// Bottom sheet for quick text capture.
class TextCaptureSheet extends ConsumerStatefulWidget {
  const TextCaptureSheet({super.key});

  @override
  ConsumerState<TextCaptureSheet> createState() => _TextCaptureSheetState();
}

class _TextCaptureSheetState extends ConsumerState<TextCaptureSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(capturesRepoProvider);
      await repo.createText(text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inboxCaptured)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.inboxError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.spaceM,
        right: Tokens.spaceM,
        bottom: bottomInset + Tokens.spaceM,
        top: Tokens.spaceM,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.inboxQuickCapture,
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: Tokens.spaceM),
          TextField(
            key: const ValueKey('text-capture-input'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l.inboxCaptureHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          SizedBox(height: Tokens.spaceS),
          Text(
            l.inboxCaptureHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: Tokens.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.cancel),
              ),
              SizedBox(width: Tokens.spaceS),
              FilledButton(
                key: const ValueKey('text-capture-save'),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(l.inboxSaveToInbox),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
