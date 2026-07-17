import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Services/database_helper.dart';

import '../mocks/fake_database.dart';

void main() {
  late FakeDatabase fakeDatabase;
  late SettingsSnapshotRepository repository;

  setUp(() async {
    fakeDatabase = await FakeDatabase.seeded();
    repository = SettingsSnapshotRepository(
      databaseHelper: DatabaseHelper(
        databaseProvider: () async => fakeDatabase.database,
      ),
    );
  });

  tearDown(() => fakeDatabase.close());

  test('maps setting and storage rows to a snapshot', () async {
    final snapshot = await repository.get();

    expect(snapshot.playedSongsMaxAmount, 0);
    expect(snapshot.storageLocations, ['/storage/emulated/0/Music']);
  });

  test('saves all snapshot values', () async {
    await repository.save(
      SettingsSnapshot(
        playedSongsMaxAmount: 2,
        storageLocations: ['/music/one', '/music/two'],
      ),
    );

    final snapshot = await repository.get();
    expect(snapshot.playedSongsMaxAmount, 2);
    expect(snapshot.storageLocations, ['/music/one', '/music/two']);
  });
}
