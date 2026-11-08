import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lifeos_app/data/db/app_database.dart';
import 'package:lifeos_app/data/repositories/repositories.dart';

/// A deterministic clock: every call advances 1 second.
class FakeClock {
  FakeClock([this.now = 1793145600000]); // 2026-10-28T00:00:00Z
  int now;
  int call() => now += 1000;
}

AppDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

Future<Repositories> openRepos(AppDatabase db, [FakeClock? clock]) {
  return Repositories.open(db, clock: (clock ?? FakeClock()).call);
}

Future<List<PendingOp>> opsFor(AppDatabase db, String rowId) {
  return (db.select(db.pendingOps)
        ..where((o) => o.rowId.equals(rowId))
        ..orderBy([(o) => OrderingTerm.asc(o.id)]))
      .get();
}
