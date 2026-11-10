// PBI-027a AC6: the API key lives in secure storage and nowhere else.
//
// Not a structural argument — this writes a key through the real
// service and then reads every value the database holds, asserting the
// key is in none of them. The export ZIP is built from this database,
// so a key that is not here cannot be in the export either.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/data/data_providers.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';
import 'package:lifeos_app/features/ai/ai_providers.dart';
import 'package:lifeos_app/features/ai/platform/secret_store.dart';

import '../../data/db_test_utils.dart';

const _secret = 'sk-proj-SUPERSECRET1234567890abcdefghij';

void main() {
  late AppDatabase db;
  late Repositories repos;
  late ProviderContainer container;
  late MemorySecretStore store;

  setUp(() async {
    db = memoryDb();
    repos = await openLocalData(db);
    store = MemorySecretStore();
    container = ProviderContainer(
      overrides: [
        repositoriesProvider.overrideWithValue(repos),
        aiSecretStoreProvider.overrideWithValue(store),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Every string the database holds, from every table that could carry
  /// a stray copy.
  Future<List<String>> everyStoredString() async {
    final values = <String>[];
    for (final row in await db.select(db.userSettings).get()) {
      row.toJson().forEach((_, v) {
        if (v != null) values.add('$v');
      });
    }
    for (final row in await db.select(db.appMeta).get()) {
      values..add(row.key)..add(row.value);
    }
    for (final row in await db.select(db.documents).get()) {
      row.toJson().forEach((_, v) {
        if (v != null) values.add('$v');
      });
    }
    return values;
  }

  test('the key reaches secure storage and never the database', () async {
    await container
        .read(aiSettingsServiceProvider)
        .setProvider(
          baseUrl: 'https://api.example.com/v1',
          model: 'gpt-4o-mini',
          apiKey: _secret,
        );

    // It is where it belongs.
    expect(await store.read(), _secret);

    // And nowhere else.
    final stored = await everyStoredString();
    for (final value in stored) {
      expect(value, isNot(contains(_secret)));
      expect(value, isNot(contains('SUPERSECRET')));
    }

    // The non-secret half is saved normally, so this test cannot pass
    // simply because nothing was written at all.
    expect(stored, contains('https://api.example.com/v1'));
    expect(stored, contains('gpt-4o-mini'));
  });

  test('clearing the key removes it from secure storage', () async {
    final service = container.read(aiSettingsServiceProvider);
    await service.setProvider(
      baseUrl: 'https://api.example.com/v1',
      model: 'm',
      apiKey: _secret,
    );
    await service.setProvider(
      baseUrl: 'https://api.example.com/v1',
      model: 'm',
      apiKey: '   ',
    );
    expect(await store.read(), isNull);
  });

  test('the settings table has no column that could hold a key', () async {
    final row = await db.select(db.userSettings).getSingleOrNull() ??
        await (db.into(db.userSettings)
              ..insert(UserSettingsCompanion.insert()))
            .insertReturning(UserSettingsCompanion.insert());
    for (final name in row.toJson().keys) {
      final lower = name.toLowerCase();
      expect(
        lower.contains('apikey') || lower.contains('secret') ||
            lower.contains('token'),
        isFalse,
        reason: 'user_settings.$name looks like somewhere a key could go',
      );
    }
  });
}
