import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../features/money/ui/expense_sheet.dart';
import '../../features/tasks/ui/new_task_sheet.dart';
import 'quick_actions.dart';

/// Whether the FAB quick-action menu is open.
class FabExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void collapse() => state = false;
}

final fabExpandedProvider = NotifierProvider<FabExpandedNotifier, bool>(
  FabExpandedNotifier.new,
);

/// One entry of the bottom bar.
class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Vertical space the floating FAB occupies above the bottom bar.
const double _fabClearance = 56 + Tokens.spaceM * 2 + Tokens.spaceS;

const _tabs = <_Tab>[
  _Tab('Home', Icons.home_outlined, Icons.home),
  _Tab('Tasks', Icons.check_circle_outline, Icons.check_circle),
  _Tab('Vault', Icons.folder_outlined, Icons.folder),
  _Tab(
    'Money',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
  ),
  _Tab('More', Icons.more_horiz, Icons.more_horiz),
];

/// The global frame: 5-tab bottom bar + expandable quick-action FAB.
/// Tab state is preserved by the router's indexed stack.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(fabExpandedProvider);
    final fab = ref.read(fabExpandedProvider.notifier);

    return PopScope(
      canPop: !expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) fab.collapse();
      },
      child: Scaffold(
        body: Stack(
          children: [
            navigationShell,
            if (expanded) ...[
              Positioned.fill(
                child: Semantics(
                  label: 'Close quick actions',
                  button: true,
                  child: GestureDetector(
                    key: const ValueKey('fab-barrier'),
                    onTap: fab.collapse,
                    child: const ColoredBox(color: Colors.black54),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  // Stack the menu above the FAB (56dp + margins) so the
                  // FAB never covers the lowest action.
                  padding: const EdgeInsets.only(bottom: _fabClearance),
                  child: _QuickActionMenu(
                    onSelected: (action) {
                      fab.collapse();
                      switch (action) {
                        case QuickAction.task:
                          showNewTaskSheet(context);
                        case QuickAction.expense:
                          showExpenseSheet(context);
                        case QuickAction.scan || QuickAction.voice:
                          showQuickActionSheet(context, action);
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('quick-action-fab'),
          tooltip: expanded ? 'Close quick actions' : 'Quick actions',
          onPressed: fab.toggle,
          child: AnimatedRotation(
            turns: expanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(Icons.add, size: 32),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            fab.collapse();
            navigationShell.goBranch(
              index,
              // Re-tapping the current tab returns to its root.
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
                tooltip: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionMenu extends StatelessWidget {
  const _QuickActionMenu({required this.onSelected});

  final ValueChanged<QuickAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in QuickAction.values)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.spaceS),
            child: FilledButton.tonal(
              key: ValueKey('quick-action-${action.name}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, Tokens.minTouchTarget),
              ),
              onPressed: () => onSelected(action),
              child: Text('${action.emoji}  ${action.label}'),
            ),
          ),
      ],
    );
  }
}
