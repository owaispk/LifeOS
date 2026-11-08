import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/task_service.dart';

/// "Now" as a local DateTime. Overridden in tests for a fixed clock.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

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

final personsProvider = StreamProvider<List<Person>>(
  (ref) => ref.watch(repositoriesProvider).persons.watchAll(),
);

final atcRuleProvider = FutureProvider.family<AtcRule?, String>(
  (ref, id) => ref.watch(repositoriesProvider).atcRules.getById(id),
);

final documentProvider = FutureProvider.family<Document?, String>(
  (ref, id) => ref.watch(repositoriesProvider).documents.getById(id),
);
