import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../data/db/app_database.dart';
import 'data/vault_service.dart';

export '../../data/data_providers.dart' show personsProvider;

final vaultServiceProvider = Provider<VaultService>(
  (ref) => VaultService(ref.watch(repositoriesProvider)),
);

/// Folders in display order (system first by seed order, then custom).
final foldersProvider = StreamProvider<List<Folder>>(
  (ref) => ref
      .watch(repositoriesProvider)
      .folders
      .watchAll()
      .map((l) => l..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
);

/// Every live document.
final documentsProvider = StreamProvider<List<Document>>(
  (ref) => ref.watch(repositoriesProvider).documents.watchAll(),
);

/// First page of each document (for thumbnails), keyed by document id.
final firstPagesProvider = StreamProvider<Map<String, DocumentFile>>(
  (ref) => ref.watch(repositoriesProvider).documentFiles.watchAll().map((
    files,
  ) {
    final first = <String, DocumentFile>{};
    for (final f in files) {
      final current = first[f.documentId];
      if (current == null || f.pageNo < current.pageNo) first[f.documentId] = f;
    }
    return first;
  }),
);
