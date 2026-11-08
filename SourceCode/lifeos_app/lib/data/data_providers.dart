import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/app_database.dart';
import 'repositories/repositories.dart';
import 'seed.dart';
import '../features/vault/data/trash_service.dart';

/// Opens the on-device database, ensures the local user, seeds defaults.
Future<Repositories> openLocalData([AppDatabase? database]) async {
  final repos = await Repositories.open(database ?? AppDatabase.open());
  await seedDefaults(repos);
  // Trash keeps deleted documents for 30 days (PBI-007).
  await TrashService(repos).purgeExpired();
  return repos;
}

/// The app's repositories. Overridden in `main()` once [openLocalData]
/// has finished, so features can read it synchronously.
final repositoriesProvider = Provider<Repositories>(
  (ref) => throw UnimplementedError(
    'repositoriesProvider must be overridden after openLocalData()',
  ),
);

/// Me / family profiles, live (shared by Tasks and Vault).
final personsProvider = StreamProvider<List<Person>>(
  (ref) => ref.watch(repositoriesProvider).persons.watchAll(),
);
