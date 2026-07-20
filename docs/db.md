# Database schema and migration proposal

## Goals

Database upgrades should:

- preserve all valid user settings, playlists, and playlist membership;
- run automatically before repositories can access the database;
- be atomic, so an interrupted or failed upgrade leaves the previous schema and
  data intact;
- support upgrading across several app releases in one launch;
- keep each schema change small, ordered, independently testable, and easy to
  review;
- never delete the database as a recovery or downgrade strategy.

The database schema version is independent of the application version in
`pubspec.yaml`. It is an integer understood by SQLite and `sqflite`; it changes
only when the database schema or stored data needs a migration.

## Proposed structure

Move schema lifecycle code out of `DatabaseHelper`. That class should remain the
application's query API, while a small database module owns opening, creating,
and upgrading the database.

```text
lib/Services/database/
  app_database.dart             # opens the database and wires callbacks
  database_schema.dart          # creates the complete latest schema
  migration.dart                # migration type and migration runner
  migrations/
    migration_to_v2.dart        # version 1 -> 2
    migration_to_v3.dart        # version 2 -> 3 (future example)
test/database/
  fixtures/
    schema_v1.dart              # creates a real old schema with sample data
    schema_v2.dart
  migration_test.dart
  schema_test.dart
```

Do not use old production migrations to create a fresh database. A fresh
installation should call one canonical `createLatestSchema` function. This
keeps installation fast and ensures that the current schema is readable in one
place. Migrations exist only to transform databases already installed by older
versions of the app.

## Migration contract and registry

Represent every upgrade as a one-version step. The target version is the
migration's identity, so `migrationToV3` always transforms version 2 into
version 3.

```dart
typedef MigrationAction = Future<void> Function(DatabaseExecutor db);

class DatabaseMigration {
  const DatabaseMigration({
    required this.toVersion,
    required this.up,
  });

  final int toVersion;
  final MigrationAction up;
}

const firstSchemaVersion = 1;

final migrations = <DatabaseMigration>[
  DatabaseMigration(toVersion: 2, up: migrateToV2),
  // DatabaseMigration(toVersion: 3, up: migrateToV3),
];

final latestSchemaVersion = migrations.isEmpty
    ? firstSchemaVersion
    : migrations.last.toVersion;
```

The registry should be validated in debug mode and tests: versions must be
unique, sorted, and contiguous. Deriving `latestSchemaVersion` from the registry
prevents a developer from adding a migration but forgetting to increment a
separate constant.

The runner applies every required step in order:

```dart
Future<void> runMigrations(
  DatabaseExecutor db,
  int oldVersion,
  int newVersion,
) async {
  for (final migration in migrations) {
    if (migration.toVersion > oldVersion &&
        migration.toVersion <= newVersion) {
      await migration.up(db);
    }
  }
}
```

For example, an upgrade from version 1 directly to version 4 executes migrations
2, 3, and 4 in that order. Migration functions must use the supplied
`DatabaseExecutor`; they must not open the database again.

## Opening and startup

`app_database.dart` should own a cached open future so the application performs
one initialization and all repositories receive the same ready database.

```dart
class AppDatabase {
  Future<Database>? _databaseFuture;

  Future<Database> open() {
    return _databaseFuture ??= _open();
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'strayker_music.db');
    return openDatabase(
      path,
      version: latestSchemaVersion,
      singleInstance: true,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await createLatestSchema(db);
        await seedInitialValues(db);
      },
      onUpgrade: runMigrations,
      onDowngrade: (db, oldVersion, newVersion) {
        throw StateError(
          'Database downgrade is unsupported: $oldVersion -> $newVersion',
        );
      },
    );
  }
}
```

The database should be explicitly opened in `main()` before repositories load
settings. `sqflite` wraps `onCreate` and `onUpgrade` in a transaction, so a
migration failure rolls back both schema and data changes and the SQLite schema
version is not advanced. Migration code must not start another transaction.

The existing native launch screen can remain visible during this initialization.
The database is small and migrations consist of local SQL, so normal upgrades
should complete without a noticeable extra screen or interaction. Migrations
must never perform network calls, scan music files, or do other unrelated work.
If startup initialization fails, log the original exception and show a retryable
startup error rather than deleting user data or starting with an empty database.

Debug-only sample playlists should not be part of production schema creation or
migrations. Seed them from a development-only bootstrap after the database has
opened, using conflict-safe inserts, so a build-mode change cannot alter user
data during migration.

## Writing safe migrations

Each migration must follow these rules:

1. Change only one version boundary, such as 2 to 3.
2. Preserve primary keys whenever other tables reference them.
3. Specify columns explicitly in every `INSERT ... SELECT`; never use
   `SELECT *`.
4. Clean or transform legacy values deliberately and document any value that
   may be discarded.
5. Make schema changes and data backfills in the same upgrade callback.
6. Do not catch SQL errors inside a migration. Let them propagate so `sqflite`
   rolls the entire upgrade back.
7. Do not modify a migration after a released build has used it. Add a new
   migration that corrects the schema or data instead.
8. Keep migrations local and deterministic: no filesystem, network, clock, or
   platform-dependent input.
9. Run `PRAGMA foreign_key_check` after table rebuilds in tests, and optionally
   at the end of an upgrade in debug builds.

### Foreign keys and table rebuilds

`sqflite` begins the upgrade transaction before calling `onUpgrade`. SQLite
cannot change `PRAGMA foreign_keys` while that transaction is active. Therefore,
a migration must not attempt to turn foreign keys off inside `onUpgrade`.

When SQLite requires a table rebuild, use foreign-key-safe ordering:

1. Create the replacement parent table under a temporary name.
2. Create the replacement child table referencing that temporary parent.
3. Copy and validate parent rows.
4. Copy child rows by joining to the replacement parent, dropping or repairing
   orphaned rows according to a documented policy.
5. Drop the old child table first.
6. Drop the old parent table.
7. Rename the replacement parent to its final name.
8. Rename the replacement child to its final name.

This avoids the current version-2 approach of disabling foreign keys inside the
upgrade transaction and dropping the old parent before its child. That approach
can fail when playlist membership rows exist.

Temporary table names should include the target version, for example
`playlists_new_v2`, to make SQL and failure reports unambiguous. Before release,
the version-1-to-2 migration should be rewritten using the ordering above and
verified with a populated version-1 database.

## Schema ownership

`database_schema.dart` should contain table-name constants and the complete
latest `CREATE TABLE` statements. Query code may share those constants, but
historical migrations should use literal legacy names and columns. Otherwise a
future rename of a current constant could silently change the meaning of an old
migration.

The latest schema should include all current constraints:

- non-null and unique setting names;
- non-null and unique storage locations;
- non-null and unique playlist names;
- non-null playlist IDs and song paths;
- a unique `(playlistId, songPath)` pair;
- a playlist foreign key with `ON DELETE CASCADE`.

Repositories and view models must not contain schema creation or migration SQL.

## Required tests

Migration tests should use `sqflite_common_ffi` and temporary file-backed
databases rather than injecting a database whose upgrade callback never runs.
For every supported historical version:

1. Create that exact old schema from a frozen test fixture.
2. Insert representative settings, playlists, membership rows, duplicates,
   nulls, and orphaned rows where the historical schema allowed them.
3. Close the database.
4. Reopen the same file through the production `AppDatabase` opener.
5. Assert the final SQLite version equals `latestSchemaVersion`.
6. Assert expected user data and IDs survived.
7. Inspect `sqlite_master` or `PRAGMA table_info` to verify the final schema.
8. Assert `PRAGMA foreign_key_check` returns no rows.

At minimum, CI should cover:

- creating a fresh latest-version database;
- upgrading version 1 to the latest version with populated playlists;
- upgrading every intermediate version to the latest version;
- opening an already-current database without changing its data;
- rollback behavior when a migration deliberately throws;
- rejection of a database newer than the app;
- registry validation for missing or duplicate versions.

Keep old schema fixtures after releases. They are the executable record of what
users may still have installed and make direct multi-release upgrade paths
reproducible.

## Developer workflow for a new schema change

To add version 3:

1. Add `migrations/migration_to_v3.dart` containing only the 2-to-3 change.
2. Append `DatabaseMigration(toVersion: 3, up: migrateToV3)` to the registry.
   The latest version is derived automatically.
3. Update `createLatestSchema` so a fresh install receives the same final
   version-3 structure.
4. Add a frozen version-2 fixture if one does not exist.
5. Add tests for 2-to-3, 1-to-3, fresh creation, preserved data, and foreign-key
   integrity.
6. Run `dart format lib test`, `flutter analyze`, and `flutter test`.

The migration and latest-schema update should be reviewed together. A release
must not ship if a database produced by fresh creation differs from one produced
by upgrading every supported historical version.

## Rollout plan

1. Introduce `AppDatabase`, the migration registry, latest schema creator, and
   file-backed migration test harness without changing repository behavior.
2. Move the existing version-1-to-2 SQL into `migration_to_v2.dart` and correct
   its foreign-key-safe rebuild order.
3. Make `DatabaseHelper` depend on `AppDatabase.open` and explicitly initialize
   it during startup.
4. Add schema-equivalence and populated-upgrade tests before the next release.
5. Use the documented one-file, one-version workflow for every later schema
   change.

This design keeps upgrades automatic and transactional for users while giving
developers an ordered migration history, one authoritative latest schema, and a
repeatable test process for every supported upgrade path.
