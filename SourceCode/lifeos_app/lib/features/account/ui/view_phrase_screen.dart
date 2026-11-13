import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../account_providers.dart';

/// Screen to view the recovery phrase (requires verification).
///
/// Since we don't store the actual phrase, this screen asks the user to
/// re-enter their phrase to verify they still have it.
class ViewPhraseScreen extends ConsumerStatefulWidget {
  const ViewPhraseScreen({super.key});

  @override
  ConsumerState<ViewPhraseScreen> createState() => _ViewPhraseScreenState();
}

class _ViewPhraseScreenState extends ConsumerState<ViewPhraseScreen> {
  final _phraseController = TextEditingController();
  bool _isVerifying = false;
  bool _isVerified = false;
  String? _error;
  RecoveryPhrase? _verifiedPhrase;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhrase() async {
    final input = _phraseController.text.trim();
    if (input.isEmpty) {
      setState(() => _error = context.l10n.acctViewEnterPhrase);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    final phrase = RecoveryPhrase.parse(input);
    if (phrase == null) {
      setState(() {
        _isVerifying = false;
        _error = context.l10n.acctRecoverInvalid;
      });
      return;
    }

    final service = ref.read(accountServiceProvider);
    final isValid = await service.verifyPhrase(phrase);

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _isVerifying = false;
        _isVerified = true;
        _verifiedPhrase = phrase;
      });
    } else {
      setState(() {
        _isVerifying = false;
        _error = context.l10n.acctViewWrongPhrase;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.acctViewPhraseTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Tokens.gutter),
          child: _isVerified && _verifiedPhrase != null
              ? _VerifiedPhraseView(phrase: _verifiedPhrase!)
              : _VerifyPhraseForm(
                  controller: _phraseController,
                  isVerifying: _isVerifying,
                  error: _error,
                  onVerify: _verifyPhrase,
                ),
        ),
      ),
    );
  }
}

class _VerifyPhraseForm extends StatelessWidget {
  const _VerifyPhraseForm({
    required this.controller,
    required this.isVerifying,
    required this.error,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool isVerifying;
  final String? error;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(Tokens.spaceM),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Tokens.radiusM),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: Tokens.spaceS),
                      Expanded(
                        child: Text(
                          l.acctViewSecurityNote,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Tokens.spaceL),

                Text(
                  l.acctViewInstruction,
                  style: theme.textTheme.bodyLarge,
                ),
                SizedBox(height: Tokens.spaceM),

                TextField(
                  key: const ValueKey('view-phrase-input'),
                  controller: controller,
                  maxLines: 4,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l.acctViewPhraseHint,
                    border: const OutlineInputBorder(),
                  ),
                ),

                if (error != null) ...[
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
                            error!,
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
          key: const ValueKey('view-phrase-verify-btn'),
          onPressed: isVerifying ? null : onVerify,
          child: isVerifying
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(l.acctViewVerifyButton),
        ),
      ],
    );
  }
}

class _VerifiedPhraseView extends StatelessWidget {
  const _VerifiedPhraseView({required this.phrase});

  final RecoveryPhrase phrase;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(width: Tokens.spaceS),
                    Text(
                      l.acctViewVerified,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Tokens.spaceL),

                Text(
                  l.acctViewYourPhrase,
                  style: theme.textTheme.bodyLarge,
                ),
                SizedBox(height: Tokens.spaceM),

                // Word grid
                Container(
                  padding: EdgeInsets.all(Tokens.spaceM),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Tokens.radiusM),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Wrap(
                    spacing: Tokens.spaceS,
                    runSpacing: Tokens.spaceS,
                    children: [
                      for (var i = 0; i < phrase.words.length; i++)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Tokens.spaceM,
                            vertical: Tokens.spaceS,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(Tokens.radiusS),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${i + 1}.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(width: Tokens.spaceXs),
                              Text(
                                phrase.words[i],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: Tokens.spaceM),

        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phrase.toPhrase()));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.acctPhraseCopied)),
            );
          },
          icon: const Icon(Icons.copy),
          label: Text(l.acctCopyPhrase),
        ),
      ],
    );
  }
}
