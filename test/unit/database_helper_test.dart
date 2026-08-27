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
        ['mediastore://external_primary/Music/'],
      );
    });

    test('replaces settings and storage locations atomically', () async {
      await databaseHelper.replaceSettingsData(
        playedSongsMaxAmount: 2,
        storageLocations: [
          'mediastore://external_primary/Rock/',
          'mediastore://external_primary/Jazz/',
        ],
      );

      expect(
        await databaseHelper.queryPlayedSongsMaxAmount(),
        {'value': '2'},
      );
      expect(
        await databaseHelper.queryStorageLocations(),
        [
          'mediastore://external_primary/Rock/',
          'mediastore://external_primary/Jazz/',
        ],
      );
    });

    test('playlist operations keep playlist and membership data consistent',
        () async {
      final playlistId = await databaseHelper.insertPlaylist('Road Trip');

      await databaseHelper.insertPlaylistSong(
        playlistId,
        'content://media/external_primary/audio/media/1',
      );
      await databaseHelper.insertPlaylistSong(
        playlistId,
        'content://media/external_primary/audio/media/2',
      );

      expect(await databaseHelper.queryPlaylists(), [
        {'id': playlistId, 'name': 'Road Trip'},
      ]);
      expect(
        await databaseHelper.queryPlaylistByName('Road Trip'),
        {'id': playlistId, 'name': 'Road Trip'},
      );
      expect(
        await databaseHelper.queryPlaylistSongPaths(playlistId),
        [
          'content://media/external_primary/audio/media/1',
          'content://media/external_primary/audio/media/2',
        ],
      );
      expect(
        await databaseHelper.queryPlaylistContainsSong(
          playlistId,
          'content://media/external_primary/audio/media/1',
        ),
        isTrue,
      );
      expect(
        await databaseHelper.queryPlaylistsContainingSong(
          'content://media/external_primary/audio/media/2',
        ),
        [
          {'id': playlistId, 'name': 'Road Trip'},
        ],
      );

      await databaseHelper.deletePlaylistSong(
        playlistId,
        'content://media/external_primary/audio/media/1',
      );
      expect(
        await databaseHelper.queryPlaylistSongPaths(playlistId),
        ['content://media/external_primary/audio/media/2'],
      );

      await databaseHelper.deletePlaylist(playlistId);
      expect(await fakeDatabase.snapshot('playlists'), isEmpty);
      expect(await fakeDatabase.snapshot('playlistSongs'), isEmpty);
    });
  });
}
