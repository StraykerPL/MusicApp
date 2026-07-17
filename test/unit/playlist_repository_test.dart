import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Repositories/playlist_repository.dart';
import 'package:strayker_music/Services/database_helper.dart';

import '../mocks/fake_database.dart';

void main() {
  late FakeDatabase fakeDatabase;
  late PlaylistRepository repository;

  setUp(() async {
    fakeDatabase = await FakeDatabase.seeded();
    repository = PlaylistRepository(
      databaseHelper: DatabaseHelper(
        databaseProvider: () async => fakeDatabase.database,
      ),
    );
  });

  tearDown(() => fakeDatabase.close());

  test('maps playlist rows and returns null when a name is missing', () async {
    final created = await repository.create('Focus');

    expect(created, const Playlist(id: 1, name: 'Focus'));
    expect(await repository.getAll(), [created]);
    expect(await repository.getByName('Focus'), created);
    expect(await repository.getByName('Missing'), isNull);
  });

  test('exposes playlist membership as paths and playlist models', () async {
    final focus = await repository.create('Focus');
    await repository.addSong(focus.id, '/music/song.mp3');

    expect(await repository.getSongPaths(focus.id), ['/music/song.mp3']);
    expect(await repository.containsSong(focus.id, '/music/song.mp3'), isTrue);
    expect(await repository.getContainingSong('/music/song.mp3'), [focus]);

    await repository.removeSong(focus.id, '/music/song.mp3');
    expect(await repository.containsSong(focus.id, '/music/song.mp3'), isFalse);
  });
}
