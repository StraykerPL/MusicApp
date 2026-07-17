import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Models/playlist.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

void main() {
  group('PlaylistManager', () {
    late FakePlaylistRepository playlistRepository;

    setUp(() {
      playlistRepository = FakePlaylistRepository();
    });

    test('constructor sorts songs and initializes All Files playlist', () {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('/music/zebra.mp3'),
          createSong('/music/alpha.mp3'),
          createSong('/music/mango.mp3'),
        ],
      );

      expect(manager.currentPlaylist, 'All Files');
      expect(manager.availablePlaylists, ['All Files']);
      expect(
        manager.currentPlaylistSongs.map((song) => song.name).toList(),
        ['alpha', 'mango', 'zebra'],
      );
    });

    test('createPlaylist returns id, reloads playlists, and notifies listeners',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [createSong('/music/alpha.mp3')],
      );
      var notifications = 0;
      manager.addListener(() => notifications++);

      final result = await manager.createPlaylist('Road Trip');

      expect(result, 1);
      expect(manager.availablePlaylists, ['All Files', 'Road Trip']);
      expect(notifications, 1);
    });

    test('getPlaylistByName returns matching playlist and null when missing',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [createSong('/music/alpha.mp3')],
      );
      await playlistRepository.create('Road Trip');
      await playlistRepository.create('Focus');

      final existing = await manager.getPlaylistByName('Focus');
      final missing = await manager.getPlaylistByName('Missing');

      expect(existing, const Playlist(id: 2, name: 'Focus'));
      expect(missing, isNull);
    });

    test(
        'switchToPlaylist updates selected playlist, songs, and notifies listeners',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('/music/alpha.mp3'),
          createSong('/music/beta.mp3'),
          createSong('/music/gamma.mp3'),
        ],
      );
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(playlistId, '/music/beta.mp3');
      await playlistRepository.addSong(playlistId, '/music/gamma.mp3');
      var notifications = 0;
      manager.addListener(() => notifications++);

      await manager.switchToPlaylist('Focus');

      expect(manager.currentPlaylist, 'Focus');
      expect(
        manager.currentPlaylistSongs.map((song) => song.filePath).toList(),
        ['/music/beta.mp3', '/music/gamma.mp3'],
      );
      expect(notifications, 1);
    });

    test(
        'getPlaylistSongsByName returns all songs for All Files and missing playlists',
        () async {
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: songs,
      );

      final allFilesSongs =
          await manager.getPlaylistSongsByName('All Files', songs);
      final missingPlaylistSongs =
          await manager.getPlaylistSongsByName('Missing', songs);

      expect(allFilesSongs, songs);
      expect(missingPlaylistSongs, songs);
    });

    test(
        'addSongToPlaylistByName adds song and refreshes current playlist when selected',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('/music/alpha.mp3'),
          createSong('/music/beta.mp3'),
        ],
      );
      await playlistRepository.create('Focus');
      await manager.switchToPlaylist('Focus');
      var notifications = 0;
      manager.addListener(() => notifications++);

      await manager.addSongToPlaylistByName('Focus', '/music/beta.mp3');

      expect(
        manager.currentPlaylistSongs.map((song) => song.filePath).toList(),
        ['/music/beta.mp3'],
      );
      expect(notifications, 1);
    });

    test(
        'removeSongFromPlaylistByName removes song and refreshes current playlist when selected',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('/music/alpha.mp3'),
          createSong('/music/beta.mp3'),
        ],
      );
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(playlistId, '/music/alpha.mp3');
      await playlistRepository.addSong(playlistId, '/music/beta.mp3');
      await manager.switchToPlaylist('Focus');

      await manager.removeSongFromPlaylistByName('Focus', '/music/beta.mp3');

      expect(
        manager.currentPlaylistSongs.map((song) => song.filePath).toList(),
        ['/music/alpha.mp3'],
      );
    });

    test(
        'deletePlaylistByName deletes playlist, reloads names, and switches back to All Files',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('/music/alpha.mp3'),
          createSong('/music/beta.mp3'),
        ],
      );
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(playlistId, '/music/alpha.mp3');
      await manager.switchToPlaylist('Focus');

      await manager.deletePlaylistByName('Focus');

      expect(manager.currentPlaylist, 'All Files');
      expect(manager.availablePlaylists, ['All Files']);
      expect(
        manager.currentPlaylistSongs.map((song) => song.filePath).toList(),
        ['/music/alpha.mp3', '/music/beta.mp3'],
      );
    });

    test(
        'isSongInPlaylist handles All Files, missing playlists, and stored songs',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [createSong('/music/alpha.mp3')],
      );
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(playlistId, '/music/beta.mp3');

      final inAllFiles =
          await manager.isSongInPlaylist('All Files', '/music/alpha.mp3');
      final inFocus =
          await manager.isSongInPlaylist('Focus', '/music/beta.mp3');
      final missing =
          await manager.isSongInPlaylist('Missing', '/music/beta.mp3');

      expect(inAllFiles, isTrue);
      expect(inFocus, isTrue);
      expect(missing, isFalse);
    });

    test(
        'getPlaylistsContainingSong returns only playlists that contain the song',
        () async {
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [createSong('/music/alpha.mp3')],
      );
      final roadTripId = (await playlistRepository.create('Road Trip')).id;
      final focusId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(roadTripId, '/music/alpha.mp3');
      await playlistRepository.addSong(focusId, '/music/beta.mp3');

      final result =
          await manager.getPlaylistsContainingSong('/music/alpha.mp3');

      expect(result, ['Road Trip']);
    });

    test('getNextSongFromPlaylist returns next song and wraps at the end', () {
      final alpha = createSong('/music/alpha.mp3');
      final beta = createSong('/music/beta.mp3');
      final gamma = createSong('/music/gamma.mp3');
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [beta, gamma, alpha],
      );

      final nextSong = manager.getNextSongFromPlaylist(alpha);
      final wrappedSong = manager.getNextSongFromPlaylist(gamma);

      expect(nextSong, beta);
      expect(wrappedSong, alpha);
    });

    test('getPreviousSongFromPlaylist returns previous song and wraps at start',
        () {
      final alpha = createSong('/music/alpha.mp3');
      final beta = createSong('/music/beta.mp3');
      final gamma = createSong('/music/gamma.mp3');
      final manager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [beta, gamma, alpha],
      );

      final previousSong = manager.getPreviousSongFromPlaylist(gamma);
      final wrappedSong = manager.getPreviousSongFromPlaylist(alpha);

      expect(previousSong, beta);
      expect(wrappedSong, gamma);
    });
  });
}
