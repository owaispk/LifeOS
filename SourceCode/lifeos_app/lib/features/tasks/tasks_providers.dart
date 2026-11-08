import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/now_provider.dart';
import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/task_service.dart';
import 'domain/overload.dart';

export '../../core/now_provider.dart';
export '../../data/data_providers.dart' show personsProvider;

final taskServiceProvider = Provider<TaskService>(
  (ref) =>
      TaskService(ref.watch(repositoriesProvider), now: ref.watch(nowProvider)),
);

/// Every non-deleted task, live.
final allTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(repositoriesProvider).tasks.watchAll(),
);

final taskByIdProvider = Provider.family<AsyncValue<Task?>, String>(
  (ref, id) => ref
      .watch(allTasksProvider)
      .whenData((tasks) => tasks.where((t) => t.id == id).firstOrNull),
);

final subtasksProvider = StreamProvider.family<List<Subtask>, String>(
  (ref, taskId) => ref.watch(taskServiceProvider).watchSubtasks(taskId),
);

final atcRuleProvider = FutureProvider.family<AtcRule?, String>(
  (ref, id) => ref.watch(repositoriesProvider).atcRules.getById(id),
);

final documentProvider = FutureProvider.family<Document?, String>(
  (ref, id) => ref.watch(repositoriesProvider).documents.getById(id),
);

/// Overload Shield day capacity in minutes (user_settings, PBI-011).
final dayCapacityProvider = StreamProvider<int>(
  (ref) => ref
      .watch(repositoriesProvider)
      .userSettings
      .watchAll()
      .map((s) => s.isEmpty ? defaultDayCapacityMin : s.first.dayCapacityMin),
);
