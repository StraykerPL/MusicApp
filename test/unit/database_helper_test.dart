import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Business/database_helper.dart';

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

    test('getAllData returns stored rows for the requested table', () async {
      final expectedRows = await fakeDatabase.snapshot('settings');

      final result = await databaseHelper.getAllData('settings');

      expect(result, expectedRows);
    });

    test('insertData stores every provided row', () async {
      final rowsToInsert = [
        {'name': '/music/rock'},
        {'name': '/music/jazz'},
      ];

      await databaseHelper.insertData('storageLocations', rowsToInsert);

      expect(
        await fakeDatabase.snapshot('storageLocations'),
        [
          {'id': 1, 'name': '/storage/emulated/0/Music'},
          {'id': 2, 'name': '/music/rock'},
          {'id': 3, 'name': '/music/jazz'},
        ],
      );
    });

    test('updateDataByName changes only the matching row', () async {
      await databaseHelper.insertData('settings', [
        {'name': 'volume', 'value': '10'},
      ]);

      await databaseHelper
          .updateDataByName('settings', 'volume', {'value': '20'});

      expect(
        await fakeDatabase.snapshot('settings'),
        [
          {'id': 1, 'name': 'playedSongsMaxAmount', 'value': '0'},
          {'id': 2, 'name': 'volume', 'value': '20'},
        ],
      );
    });

    test('cleanTable removes all rows from the selected table', () async {
      await databaseHelper.cleanTable('playlists');

      expect(await fakeDatabase.snapshot('playlists'), isEmpty);
    });

    test('playlist operations keep playlist and song data consistent',
        () async {
      final playlistId = await databaseHelper.createPlaylist('Road Trip');

      await databaseHelper.addSongToPlaylist(playlistId, '/songs/one.mp3');
      await databaseHelper.addSongToPlaylist(playlistId, '/songs/two.mp3');
      final createdPlaylists = await databaseHelper.getPlaylists();
      final createdSongs = await databaseHelper.getPlaylistSongs(playlistId);

      expect(
        createdPlaylists,
        equals([
          {'name': 'Road Trip', 'id': playlistId}
        ]),
      );
      expect(
        createdSongs,
        [
          {'id': 1, 'playlistId': playlistId, 'songPath': '/songs/one.mp3'},
          {'id': 2, 'playlistId': playlistId, 'songPath': '/songs/two.mp3'},
        ],
      );

      await databaseHelper.removeSongFromPlaylist(playlistId, '/songs/one.mp3');

      expect(
        await fakeDatabase.snapshot('playlistSongs'),
        [
          {'id': 2, 'playlistId': playlistId, 'songPath': '/songs/two.mp3'},
        ],
      );

      await databaseHelper.deletePlaylist(playlistId);

      expect(await fakeDatabase.snapshot('playlists'), isEmpty);
      expect(await fakeDatabase.snapshot('playlistSongs'), isEmpty);
    });
  });
}
