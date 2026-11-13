import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/data_providers.dart';
import '../account_providers.dart';

/// Verifies the user wrote down the phrase by asking for 3 random words.
class VerifyPhraseScreen extends ConsumerStatefulWidget {
  const VerifyPhraseScreen({super.key});

  @override
  ConsumerState<VerifyPhraseScreen> createState() => _VerifyPhraseScreenState();
}

class _VerifyPhraseScreenState extends ConsumerState<VerifyPhraseScreen> {
  final _controllers = <TextEditingController>[];
  final _focusNodes = <FocusNode>[];
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 3; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }
  }

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

  Future<void> _verify() async {
    final state = ref.read(accountCreationProvider);
    final challenge = state.challenge;
    if (challenge == null) return;

    final answers = _controllers.map((c) => c.text.trim()).toList();

    // Check if all fields are filled.
    if (answers.any((a) => a.isEmpty)) {
      setState(() => _error = context.l10n.acctVerifyFillAll);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    // Enter each answer into the notifier.
    final notifier = ref.read(accountCreationProvider.notifier);
    for (var i = 0; i < challenge.indices.length; i++) {
      notifier.enterWord(challenge.indices[i], answers[i]);
    }

    final isValid = notifier.verifyChallenge();

    if (!isValid) {
      setState(() {
        _isVerifying = false;
        _error = context.l10n.acctVerifyWrong;
      });
      return;
    }

    // Get the user id from the database.
    final db = ref.read(repositoriesProvider).db;
    final settings = await db.select(db.userSettings).getSingleOrNull();
    final userId = settings?.userId ?? '';

    // Create the account.
    try {
      await notifier.createAccount(userId);

      if (!mounted) return;

      // Invalidate the account provider to refresh.
      ref.invalidate(activeAccountProvider);
      ref.invalidate(hasAccountProvider);

      // Show success and go back to settings.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.acctCreated)),
      );
      context.go('/more/settings');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(accountCreationProvider);
    final challenge = state.challenge;

    if (challenge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(recoveryPhraseRoute);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.acctVerifyTitle),
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
                        l.acctVerifyInstruction,
                        style: theme.textTheme.bodyLarge,
                      ),
                      SizedBox(height: Tokens.spaceL),

                      // Input fields for each word.
                      for (var i = 0; i < challenge.indices.length; i++) ...[
                        _WordInput(
                          key: ValueKey('verify-word-$i'),
                          wordNumber: challenge.indices[i] + 1,
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onSubmitted: (_) {
                            if (i < challenge.indices.length - 1) {
                              _focusNodes[i + 1].requestFocus();
                            } else {
                              _verify();
                            }
                          },
                        ),
                        if (i < challenge.indices.length - 1)
                          SizedBox(height: Tokens.spaceM),
                      ],

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
                key: const ValueKey('verify-submit-btn'),
                onPressed: _isVerifying ? null : _verify,
                child: _isVerifying
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(l.acctVerifyButton),
              ),

              SizedBox(height: Tokens.spaceS),

              TextButton(
                onPressed: () => context.go(recoveryPhraseRoute),
                child: Text(l.acctVerifyGoBack),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordInput extends StatelessWidget {
  const _WordInput({
    super.key,
    required this.wordNumber,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final int wordNumber;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.acctVerifyWordN('$wordNumber'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: Tokens.spaceXs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: l.acctVerifyWordHint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}
