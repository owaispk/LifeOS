import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../account_providers.dart';

/// Shows the generated recovery phrase and asks user to write it down.
class RecoveryPhraseScreen extends ConsumerStatefulWidget {
  const RecoveryPhraseScreen({super.key});

  @override
  ConsumerState<RecoveryPhraseScreen> createState() =>
      _RecoveryPhraseScreenState();
}

class _RecoveryPhraseScreenState extends ConsumerState<RecoveryPhraseScreen> {
  bool _hasConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(accountCreationProvider);
    final phrase = state.phrase;

    if (phrase == null) {
      // Navigate back if no phrase was generated.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(createAccountRoute);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.acctRecoveryPhrase),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l.acctCopyPhrase,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: phrase.toPhrase()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.acctPhraseCopied)),
              );
            },
          ),
        ],
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
                      // Warning banner
                      Container(
                        padding: EdgeInsets.all(Tokens.spaceM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(Tokens.radiusM),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: theme.colorScheme.error,
                            ),
                            SizedBox(width: Tokens.spaceS),
                            Expanded(
                              child: Text(
                                l.acctPhraseWarning,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: Tokens.spaceL),

                      Text(
                        l.acctPhraseInstruction,
                        style: theme.textTheme.bodyLarge,
                      ),
                      SizedBox(height: Tokens.spaceL),

                      // Word grid
                      _PhraseGrid(words: phrase.words),
                      SizedBox(height: Tokens.spaceL),

                      // Tips
                      Text(
                        l.acctPhraseTips,
                        style: theme.textTheme.titleMedium,
                      ),
                      SizedBox(height: Tokens.spaceS),
                      _TipItem(text: l.acctPhraseTip1),
                      _TipItem(text: l.acctPhraseTip2),
                      _TipItem(text: l.acctPhraseTip3),
                    ],
                  ),
                ),
              ),

              SizedBox(height: Tokens.spaceM),

              // Confirmation checkbox
              CheckboxListTile(
                key: const ValueKey('phrase-confirm-check'),
                value: _hasConfirmed,
                onChanged: (v) => setState(() => _hasConfirmed = v ?? false),
                title: Text(l.acctPhraseConfirmLabel),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              SizedBox(height: Tokens.spaceS),

              FilledButton(
                key: const ValueKey('phrase-continue-btn'),
                onPressed: _hasConfirmed
                    ? () {
                        ref
                            .read(accountCreationProvider.notifier)
                            .createChallenge();
                        context.go(verifyPhraseRoute);
                      }
                    : null,
                child: Text(l.acctPhraseVerify),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays the 12 words in a numbered grid.
class _PhraseGrid extends StatelessWidget {
  const _PhraseGrid({required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(Tokens.spaceM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Tokens.radiusM),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: Tokens.spaceS,
        runSpacing: Tokens.spaceS,
        children: [
          for (var i = 0; i < words.length; i++)
            _WordChip(number: i + 1, word: words[i]),
        ],
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.number, required this.word});

  final int number;
  final String word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.spaceM,
        vertical: Tokens.spaceS,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusS),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$number.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: Tokens.spaceXs),
          Text(
            word,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: Tokens.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: theme.textTheme.bodyMedium),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
