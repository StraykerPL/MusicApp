import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Services/database_helper.dart';

import '../mocks/fake_database.dart';

void main() {
  group('DatabaseHelper', () {
    late FakeDatabase fakeDatabase;
    late DatabaseHelper databaseHelper;

    setUp(() async {
      fakeDatabase = await FakeDatabase.seeded();
      databaseHelper =
          DatabaseHelper(databaseProvider: () async => fakeDatabase.database);
    });

    tearDown(() async {
      await fakeDatabase.close();
    });

    test('queries seeded settings data', () async {
      expect(
        await databaseHelper.queryPlayedSongsMaxAmount(),
        {'value': '0'},
      );
      expect(
        await databaseHelper.queryStorageLocations(),
        ['/storage/emulated/0/Music'],
      );
    });

    test('replaces settings and storage locations atomically', () async {
      await databaseHelper.replaceSettingsData(
        playedSongsMaxAmount: 2,
        storageLocations: ['/music/rock', '/music/jazz'],
      );

      expect(
        await databaseHelper.queryPlayedSongsMaxAmount(),
        {'value': '2'},
      );
      expect(
        await databaseHelper.queryStorageLocations(),
        ['/music/rock', '/music/jazz'],
      );
    });

    test('playlist operations keep playlist and membership data consistent',
        () async {
      final playlistId = await databaseHelper.insertPlaylist('Road Trip');

      await databaseHelper.insertPlaylistSong(playlistId, '/songs/one.mp3');
      await databaseHelper.insertPlaylistSong(playlistId, '/songs/two.mp3');

      expect(await databaseHelper.queryPlaylists(), [
        {'id': playlistId, 'name': 'Road Trip'},
      ]);
      expect(
        await databaseHelper.queryPlaylistByName('Road Trip'),
        {'id': playlistId, 'name': 'Road Trip'},
      );
      expect(
        await databaseHelper.queryPlaylistSongPaths(playlistId),
        ['/songs/one.mp3', '/songs/two.mp3'],
      );
      expect(
        await databaseHelper.queryPlaylistContainsSong(
          playlistId,
          '/songs/one.mp3',
        ),
        isTrue,
      );
      expect(
        await databaseHelper.queryPlaylistsContainingSong('/songs/two.mp3'),
        [
          {'id': playlistId, 'name': 'Road Trip'},
        ],
      );

      await databaseHelper.deletePlaylistSong(playlistId, '/songs/one.mp3');
      expect(
        await databaseHelper.queryPlaylistSongPaths(playlistId),
        ['/songs/two.mp3'],
      );

      await databaseHelper.deletePlaylist(playlistId);
      expect(await fakeDatabase.snapshot('playlists'), isEmpty);
      expect(await fakeDatabase.snapshot('playlistSongs'), isEmpty);
    });
  });
}
