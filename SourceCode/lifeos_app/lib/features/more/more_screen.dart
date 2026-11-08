import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../shared/widgets/tab_scaffold.dart';

/// 5. MORE — menu (UI flow §5). Auto Tasks (PBI-017) and Trash (PBI-007)
/// now; Health, People, Work, Soul and Settings arrive with their PBIs.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      title: 'More',
      body: ListView(
        key: const ValueKey('more-menu'),
        padding: const EdgeInsets.symmetric(vertical: Tokens.spaceS),
        children: [
          ListTile(
            key: const ValueKey('more-atc'),
            leading: const Text('⚡', style: TextStyle(fontSize: 24)),
            title: const Text('Auto Tasks'),
            subtitle: const Text('Rules that create payment tasks for you'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/atc'),
          ),
          ListTile(
            key: const ValueKey('more-trash'),
            leading: const Text('🗑️', style: TextStyle(fontSize: 24)),
            title: const Text('Trash'),
            subtitle: const Text('Deleted documents, kept for 30 days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/vault/trash'),
          ),
        ],
      ),
    );
  }
}
