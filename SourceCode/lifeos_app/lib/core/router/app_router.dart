import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../shared/widgets/app_shell.dart';

abstract final class Routes {
  static const home = '/home';
  static const tasks = '/tasks';
  static const vault = '/vault';
  static const money = '/money';
  static const more = '/more';
}

/// One router per ProviderScope, so tests always start fresh.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(Routes.tasks, const TasksScreen()),
          _branch(Routes.vault, const VaultScreen()),
          _branch(Routes.money, const MoneyScreen()),
          _branch(Routes.more, const MoreScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) {
  return StatefulShellBranch(
    routes: [
      GoRoute(path: path, builder: (context, state) => screen),
    ],
  );
}
