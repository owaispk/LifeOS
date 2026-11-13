// Riverpod providers for Quick Capture Inbox (PBI-026).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/captures_repo.dart';
import 'data/inbox_service.dart';

/// The captures repository.
final capturesRepoProvider = Provider<CapturesRepository>(
  (ref) => CapturesRepository(
    ref.watch(repositoriesProvider),
    now: ref.watch(nowProvider),
  ),
);

/// The inbox service for classification and handoff.
final inboxServiceProvider = Provider<InboxService>(
  (ref) => InboxService(
    ref.watch(repositoriesProvider),
    capturesRepo: ref.watch(capturesRepoProvider),
    now: ref.watch(nowProvider),
  ),
);

/// All pending captures, newest first (live).
final pendingCapturesProvider = StreamProvider<List<Capture>>(
  (ref) => ref.watch(capturesRepoProvider).watchPending(),
);

/// Count of pending captures for badge display.
final pendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(capturesRepoProvider).watchPendingCount(),
);

/// Single capture by id.
final captureByIdProvider = Provider.family<AsyncValue<Capture?>, String>(
  (ref, id) => ref.watch(pendingCapturesProvider).whenData(
    (captures) => captures.where((c) => c.id == id).firstOrNull,
  ),
);
