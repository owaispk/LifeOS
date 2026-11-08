import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/data_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The web build is a UI preview only for now: Drift on web needs the
  // sqlite3.wasm/worker assets, which are not part of the MVP.
  final repos = kIsWeb ? null : await openLocalData();

  runApp(
    ProviderScope(
      overrides: [
        if (repos != null) repositoriesProvider.overrideWithValue(repos),
      ],
      child: const LifeOsApp(),
    ),
  );
}
