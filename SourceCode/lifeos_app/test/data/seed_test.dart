// PBI-002 AC5: a fresh install is seeded, and re-seeding adds nothing.
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/seed.dart';

import 'db_test_utils.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = memoryDb());
  tearDown(() => db.close());

  test(
    'fresh install has Me, 8 system folders, categories, settings',
    () async {
      final r = await openLocalData(db);

      final people = await r.persons.getAll();
      expect(people.map((p) => (p.name, p.relation)), [('Me', 'self')]);

      final folders = await r.folders.getAll();
      expect(folders.map((f) => f.kind).toSet(), {
        'identity',
        'education',
        'medical',
        'bills',
        'property',
        'vehicles',
        'insurance',
        'work',
      });
      expect(folders.map((f) => f.name), contains('Bills & Receipts'));

      final categories = await r.categories.getAll();
      expect(categories.map((c) => c.systemKey).toSet(), {
        'rent',
        'fees',
        'utilities',
        'internet',
        'mobile',
        'installment',
        'subscription',
        'other',
      });

      final settings = await r.userSettings.getAll();
      expect(settings, hasLength(1));
      expect(settings.single.themeTemplate, 'flagship');
      expect(settings.single.quietStart, '22:00');
      expect(settings.single.digestTime, '07:30');
      expect(settings.single.vaultLock, isTrue);

      // Seeded rows are owned by the local user and queued for sync.
      expect(folders.every((f) => f.userId == r.context.userId), isTrue);
      final ops = await db.select(db.pendingOps).get();
      expect(ops, hasLength(1 + 8 + 8 + 1));
    },
  );

  test('seeding again creates no duplicates', () async {
    final r = await openLocalData(db);
    await seedDefaults(r);
    await seedDefaults(r);

    expect(await r.persons.getAll(), hasLength(1));
    expect(await r.folders.getAll(), hasLength(8));
    expect(await r.categories.getAll(), hasLength(8));
    expect(await r.userSettings.getAll(), hasLength(1));
  });

  test('seeding keeps user-created data and only fills gaps', () async {
    final r = await openLocalData(db);
    final work = (await r.folders.getAll()).firstWhere((f) => f.kind == 'work');
    await r.folders.update(work.id, const FoldersCompanion());

    await seedDefaults(r);
    final works = (await r.folders.getAll())
        .where((f) => f.kind == 'work')
        .toList();
    expect(works, hasLength(1));
    expect(works.single.id, work.id);
  });
}
