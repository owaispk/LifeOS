import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/theme/tokens.dart';
import '../account_providers.dart';

/// Initial screen for optional account creation.
///
/// Explains the benefits of creating an account with a recovery phrase.
class CreateAccountScreen extends ConsumerWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.acctCreateTitle),
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
                      // Hero icon
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.key_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: Tokens.spaceL),

                      // Title
                      Text(
                        l.acctWhyCreate,
                        style: theme.textTheme.headlineSmall,
                      ),
                      SizedBox(height: Tokens.spaceM),

                      // Benefits list
                      _BenefitItem(
                        icon: Icons.devices,
                        title: l.acctBenefitRecover,
                        subtitle: l.acctBenefitRecoverDesc,
                      ),
                      SizedBox(height: Tokens.spaceM),
                      _BenefitItem(
                        icon: Icons.lock_outline,
                        title: l.acctBenefitSecure,
                        subtitle: l.acctBenefitSecureDesc,
                      ),
                      SizedBox(height: Tokens.spaceM),
                      _BenefitItem(
                        icon: Icons.offline_bolt_outlined,
                        title: l.acctBenefitOffline,
                        subtitle: l.acctBenefitOfflineDesc,
                      ),
                      SizedBox(height: Tokens.spaceL),

                      // Info box
                      Container(
                        padding: EdgeInsets.all(Tokens.spaceM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(Tokens.radiusM),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: Tokens.spaceS),
                            Expanded(
                              child: Text(
                                l.acctNoServerNote,
                                style: theme.textTheme.bodySmall,
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

              // Action buttons
              FilledButton.icon(
                key: const ValueKey('create-account-btn'),
                onPressed: () {
                  ref.read(accountCreationProvider.notifier).generatePhrase();
                  context.go(recoveryPhraseRoute);
                },
                icon: const Icon(Icons.add),
                label: Text(l.acctCreateButton),
              ),
              SizedBox(height: Tokens.spaceS),
              OutlinedButton(
                key: const ValueKey('recover-account-btn'),
                onPressed: () => context.go(recoverAccountRoute),
                child: Text(l.acctRecoverExisting),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(Tokens.spaceS),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(Tokens.radiusS),
          ),
          child: Icon(
            icon,
            size: 24,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(width: Tokens.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: Tokens.spaceXs),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
