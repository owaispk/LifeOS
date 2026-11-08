import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/capture_entry.dart';
import '../../features/capture/review_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/tasks/ui/task_detail_screen.dart';
import '../../features/vault/vault_list_screen.dart';
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
      // Full-screen capture confirm step, above the tabs (PBI-003).
      GoRoute(
        path: captureRoute,
        builder: (context, state) => const CaptureReviewScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(Routes.home, const HomeScreen()),
          _branch(
            Routes.tasks,
            const TasksScreen(),
            routes: [
              GoRoute(
                path: 'task/:id',
                builder: (context, state) =>
                    TaskDetailScreen(taskId: state.pathParameters['id']!),
              ),
            ],
          ),
          _branch(
            Routes.vault,
            const VaultScreen(),
            routes: [
              GoRoute(
                path: 'folder/:id',
                builder: (context, state) => VaultListScreen(
                  scope: FolderScope(state.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: 'person/:id',
                builder: (context, state) => VaultListScreen(
                  scope: PersonScope(state.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: 'unfiled',
                builder: (context, state) =>
                    const VaultListScreen(scope: UnfiledScope()),
              ),
            ],
          ),
          _branch(Routes.money, const MoneyScreen()),
          _branch(Routes.more, const MoreScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(
  String path,
  Widget screen, {
  List<RouteBase> routes = const [],
}) {
  return StatefulShellBranch(
    routes: [
      GoRoute(path: path, builder: (context, state) => screen, routes: routes),
    ],
  );
}
