import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/tab_scaffold.dart';
import '../profile/profile_screen.dart' show selfPersonProvider;

/// 5. MORE — menu (UI flow §5). My Profile (PBI-035), Auto Tasks (PBI-017),
/// Settings and Trash (PBI-007); Health, People, Work and Soul arrive with
/// their PBIs.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final self = ref.watch(selfPersonProvider);
    final named = self != null && self.name.trim() != 'Me';
    return TabScaffold(
      title: context.l10n.mrTitle,
      body: ListView(
        key: const ValueKey('more-menu'),
        padding: EdgeInsets.symmetric(vertical: Tokens.spaceS),
        children: [
          ListTile(
            key: const ValueKey('more-profile'),
            leading: Text(
              self?.avatar ?? '👤',
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(context.l10n.mrProfile),
            subtitle: Text(named ? self.name : context.l10n.mrProfileSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/profile'),
          ),
          ListTile(
            key: const ValueKey('more-atc'),
            leading: const Text('⚡', style: TextStyle(fontSize: 24)),
            title: Text(context.l10n.mrAutoTasks),
            subtitle: Text(context.l10n.mrAutoTasksSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/atc'),
          ),
          ListTile(
            key: const ValueKey('more-settings'),
            leading: const Text('⚙️', style: TextStyle(fontSize: 24)),
            title: Text(context.l10n.moreSettings),
            subtitle: Text(context.l10n.moreSettingsSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/more/settings'),
          ),
          ListTile(
            key: const ValueKey('more-trash'),
            leading: const Text('🗑️', style: TextStyle(fontSize: 24)),
            title: Text(context.l10n.trash),
            subtitle: Text(context.l10n.mrTrashSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/vault/trash'),
          ),
        ],
      ),
    );
  }
}
