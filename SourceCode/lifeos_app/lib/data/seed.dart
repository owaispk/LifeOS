import 'package:drift/drift.dart';

import 'db/app_database.dart';
import 'repositories/repositories.dart';

/// System folders (features spec §1.3), in display order.
const systemFolders = <({String kind, String name, String icon})>[
  (kind: 'identity', name: 'Identity', icon: '🪪'),
  (kind: 'education', name: 'Education', icon: '🎓'),
  (kind: 'medical', name: 'Medical', icon: '🏥'),
  (kind: 'bills', name: 'Bills & Receipts', icon: '🧾'),
  (kind: 'property', name: 'Property', icon: '🏠'),
  (kind: 'vehicles', name: 'Vehicles', icon: '🚗'),
  (kind: 'insurance', name: 'Insurance', icon: '🛡️'),
  (kind: 'work', name: 'Work', icon: '💼'),
];

/// System expense categories (data model §3.4 `system_key`).
const systemCategories = <({String key, String name, String icon})>[
  (key: 'rent', name: 'Rent', icon: '🏠'),
  (key: 'fees', name: 'Fees & Tuition', icon: '🎓'),
  (key: 'utilities', name: 'Utilities', icon: '💡'),
  (key: 'internet', name: 'Internet', icon: '🌐'),
  (key: 'mobile', name: 'Mobile', icon: '📱'),
  (key: 'installment', name: 'Installments', icon: '📆'),
  (key: 'subscription', name: 'Subscriptions', icon: '🔁'),
  (key: 'other', name: 'Other', icon: '🧾'),
];

/// Creates first-run data. Idempotent: each item is matched by its natural
/// key (person relation `self`, folder `kind`, category `system_key`,
/// one settings row per user) and only created if missing.
Future<void> seedDefaults(Repositories repos) {
  final db = repos.db;
  return db.transaction(() async {
    final people = await repos.persons.getAll();
    if (!people.any((p) => p.relation == 'self')) {
      await repos.persons.insert(PersonsCompanion.insert(
        name: 'Me',
        relation: const Value('self'),
        avatar: const Value('🙂'),
      ));
    }

    final folderKinds = (await repos.folders.getAll()).map((f) => f.kind).toSet();
    for (final (i, f) in systemFolders.indexed) {
      if (folderKinds.contains(f.kind)) continue;
      await repos.folders.insert(FoldersCompanion.insert(
        name: f.name,
        icon: Value(f.icon),
        kind: Value(f.kind),
        sortOrder: Value(i),
      ));
    }

    final categoryKeys =
        (await repos.categories.getAll()).map((c) => c.systemKey).toSet();
    for (final c in systemCategories) {
      if (categoryKeys.contains(c.key)) continue;
      await repos.categories.insert(CategoriesCompanion.insert(
        name: c.name,
        icon: Value(c.icon),
        systemKey: Value(c.key),
      ));
    }

    if ((await repos.userSettings.getAll()).isEmpty) {
      await repos.userSettings.insert(const UserSettingsCompanion());
    }
  });
}
