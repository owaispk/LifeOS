import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../log/app_log.dart';

import '../../features/account/ui/create_account_screen.dart';
import '../../features/account/ui/recover_account_screen.dart';
import '../../features/account/ui/recovery_phrase_screen.dart';
import '../../features/account/ui/verify_phrase_screen.dart';
import '../../features/account/ui/view_phrase_screen.dart';
import '../../features/ai/ui/ai_settings_screen.dart';
import '../../features/brief/ui/brief_screen.dart';
import '../../features/brief/ui/brief_settings_screen.dart';
import '../../features/atc/atc_rules_screen.dart';
import '../../features/atc/rule_detail_screen.dart';
import '../../features/capture/capture_entry.dart';
import '../../features/capture/review_screen.dart';
import '../../features/home/attention_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/inbox/ui/inbox_screen.dart';
import '../../features/money/money_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/premium/ui/premium_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/score/score_screen.dart';
import '../../features/settings/diagnostics_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/completed_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/tasks/ui/task_detail_screen.dart';
import '../../features/vault/bundle_screen.dart';
import '../../features/vault/document_viewer_screen.dart';
import '../../features/vault/expiring_screen.dart';
import '../../features/vault/share_history_screen.dart';
import '../../features/vault/trash_screen.dart';
import '../../features/vault/vault_list_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../../features/security/lock_gate.dart';
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
  // Onboarding shows until it is finished or skipped (PBI-022 AC1).
  final refresh = ValueNotifier(0);
  ref.listen(onboardingDoneProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider).value;
      if (done == null) return null; // loading, or no local database
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!done && !atOnboarding) return '/onboarding';
      if (done && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Full-screen document viewer, above the tabs (PBI-007).
      GoRoute(
        path: '/doc/:id',
        builder: (context, state) => VaultGate(
          child: DocumentViewerScreen(documentId: state.pathParameters['id']!),
        ),
      ),
      // Share as one PDF, above the tabs (PBI-028a).
      GoRoute(
        path: bundleRoute,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return VaultGate(
            child: BundleScreen(
              ids: [
                for (final id in (q['ids'] ?? '').split(','))
                  if (id.isNotEmpty) id,
              ],
              pack: q['pack'],
              preset: q['preset'],
            ),
          );
        },
      ),
      // Full-screen capture confirm step, above the tabs (PBI-003).
      GoRoute(
        path: captureRoute,
        builder: (context, state) => const CaptureReviewScreen(),
      ),
      // Daily Voice Brief (PBI-039a).
      GoRoute(
        path: briefRoute,
        builder: (context, state) => const BriefScreen(),
      ),
      // Quick Capture Inbox (PBI-026).
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const InboxScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(
            Routes.home,
            const HomeScreen(),
            routes: [
              GoRoute(
                path: 'score',
                builder: (context, state) => const ScoreScreen(),
              ),
              GoRoute(
                path: 'attention',
                builder: (context, state) => const AttentionScreen(),
              ),
            ],
          ),
          _branch(
            Routes.tasks,
            const TasksScreen(),
            routes: [
              GoRoute(
                path: 'completed',
                builder: (context, state) => const CompletedTasksScreen(),
              ),
              GoRoute(
                path: 'task/:id',
                builder: (context, state) =>
                    TaskDetailScreen(taskId: state.pathParameters['id']!),
              ),
            ],
          ),
          _branch(
            Routes.vault,
            const VaultGate(child: VaultScreen()),
            routes: [
              GoRoute(
                path: 'folder/:id',
                builder: (context, state) => VaultGate(
                  child: VaultListScreen(
                    scope: FolderScope(state.pathParameters['id']!),
                  ),
                ),
              ),
              GoRoute(
                path: 'person/:id',
                builder: (context, state) => VaultGate(
                  child: VaultListScreen(
                    scope: PersonScope(state.pathParameters['id']!),
                  ),
                ),
              ),
              GoRoute(
                path: 'expiring',
                builder: (context, state) =>
                    VaultGate(child: const ExpiringScreen()),
              ),
              GoRoute(
                path: 'trash',
                builder: (context, state) =>
                    VaultGate(child: const TrashScreen()),
              ),
              GoRoute(
                path: 'packs',
                builder: (context, state) =>
                    const VaultGate(child: SharePacksScreen()),
              ),
              GoRoute(
                path: 'unfiled',
                builder: (context, state) => const VaultGate(
                  child: VaultListScreen(scope: UnfiledScope()),
                ),
              ),
            ],
          ),
          _branch(Routes.money, const MoneyScreen()),
          _branch(
            Routes.more,
            const MoreScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'premium',
                builder: (context, state) => const PremiumScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'shares',
                    builder: (context, state) => const ShareHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'diagnostics',
                    builder: (context, state) => const DiagnosticsScreen(),
                  ),
                  GoRoute(
                    path: 'ai',
                    builder: (context, state) => const AiSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'brief',
                    builder: (context, state) => const BriefSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'account/create',
                    builder: (context, state) => const CreateAccountScreen(),
                  ),
                  GoRoute(
                    path: 'account/phrase',
                    builder: (context, state) => const RecoveryPhraseScreen(),
                  ),
                  GoRoute(
                    path: 'account/verify',
                    builder: (context, state) => const VerifyPhraseScreen(),
                  ),
                  GoRoute(
                    path: 'account/recover',
                    builder: (context, state) => const RecoverAccountScreen(),
                  ),
                  GoRoute(
                    path: 'account/view-phrase',
                    builder: (context, state) => const ViewPhraseScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'atc',
                builder: (context, state) => const AtcRulesScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        RuleDetailScreen(ruleId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // The current screen goes with every log line (PBI-030).
  void track() {
    final route = router.state.matchedLocation;
    if (route != AppLog.currentRoute) {
      AppLog.currentRoute = route;
      AppLog.i('nav', route);
    }
  }

  router.routerDelegate.addListener(track);
  ref.onDispose(() => router.routerDelegate.removeListener(track));
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
