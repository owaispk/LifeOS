import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../account_providers.dart';

/// Screen for recovering an existing account using the recovery phrase.
class RecoverAccountScreen extends ConsumerStatefulWidget {
  const RecoverAccountScreen({super.key});

  @override
  ConsumerState<RecoverAccountScreen> createState() =>
      _RecoverAccountScreenState();
}

class _RecoverAccountScreenState extends ConsumerState<RecoverAccountScreen> {
  final _controllers = List.generate(12, (_) => TextEditingController());
  final _focusNodes = List.generate(12, (_) => FocusNode());
  bool _isRecovering = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _buildPhraseString() {
    return _controllers.map((c) => c.text.trim().toLowerCase()).join(' ');
  }

  bool _validateInput() {
    final words = _controllers.map((c) => c.text.trim()).toList();
    if (words.any((w) => w.isEmpty)) {
      setState(() => _error = context.l10n.acctRecoverFillAll);
      return false;
    }
    // Try to parse the phrase.
    final phrase = RecoveryPhrase.parse(_buildPhraseString());
    if (phrase == null) {
      setState(() => _error = context.l10n.acctRecoverInvalid);
      return false;
    }
    return true;
  }

  Future<void> _recover() async {
    if (!_validateInput()) return;

    setState(() {
      _isRecovering = true;
      _error = null;
    });

    final phraseString = _buildPhraseString();
    final success = await ref
        .read(accountRecoveryProvider.notifier)
        .recoverWithPhrase(phraseString);

    if (!mounted) return;

    if (success) {
      // Refresh account state.
      ref.invalidate(activeAccountProvider);
      ref.invalidate(hasAccountProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.acctRecovered)),
      );
      context.go('/more/settings');
    } else {
      final state = ref.read(accountRecoveryProvider);
      setState(() {
        _isRecovering = false;
        _error = state.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.acctRecoverTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.acctRecoverInstruction,
                        style: theme.textTheme.bodyLarge,
                      ),
                      SizedBox(height: Tokens.spaceL),

                      // Word input grid.
                      _WordInputGrid(
                        controllers: _controllers,
                        focusNodes: _focusNodes,
                        onLastSubmit: _recover,
                      ),

                      if (_error != null) ...[
                        SizedBox(height: Tokens.spaceM),
                        Container(
                          padding: EdgeInsets.all(Tokens.spaceM),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(Tokens.radiusM),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                              ),
                              SizedBox(width: Tokens.spaceS),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              SizedBox(height: Tokens.spaceM),

              FilledButton(
                key: const ValueKey('recover-submit-btn'),
                onPressed: _isRecovering ? null : _recover,
                child: _isRecovering
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(l.acctRecoverButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordInputGrid extends StatelessWidget {
  const _WordInputGrid({
    required this.controllers,
    required this.focusNodes,
    required this.onLastSubmit,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback onLastSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Padding(
            padding: EdgeInsets.only(bottom: Tokens.spaceS),
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: col < 2 ? Tokens.spaceS : 0,
                      ),
                      child: _buildWordField(
                        context,
                        row * 3 + col,
                        theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWordField(
    BuildContext context,
    int index,
    ThemeData theme,
  ) {
    return TextField(
      key: ValueKey('recover-word-$index'),
      controller: controllers[index],
      focusNode: focusNodes[index],
      autocorrect: false,
      textInputAction:
          index < 11 ? TextInputAction.next : TextInputAction.done,
      style: theme.textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Tokens.spaceS,
          vertical: Tokens.spaceS,
        ),
        border: const OutlineInputBorder(),
        labelText: '${index + 1}',
        labelStyle: theme.textTheme.labelSmall,
      ),
      onSubmitted: (_) {
        if (index < 11) {
          focusNodes[index + 1].requestFocus();
        } else {
          onLastSubmit();
        }
      },
    );
  }
}
