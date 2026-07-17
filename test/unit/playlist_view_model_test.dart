import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

void main() {
  group('PlaylistViewModel', () {
    late FakePlaylistRepository playlistRepository;
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late PlaylistManager playlistManager;
    late MockSoundPlayer soundPlayer;
    late SoundCollectionManager soundCollectionManager;
    late PlaylistViewModel viewModel;
    late StreamController<PlaybackState> playbackStates;
    late List<MusicFile> songs;
    late bool isViewModelDisposed;
    NotificationSkipHandler? skipToNext;
    NotificationSkipHandler? skipToPrevious;

    setUp(() {
      playlistRepository = FakePlaylistRepository();
      settingsSnapshotRepository = FakeSettingsSnapshotRepository();
      isViewModelDisposed = false;
      songs = [
        createSong('/music/gamma.mp3'),
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];
      playlistManager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: songs,
      );
      soundPlayer = MockSoundPlayer();
      playbackStates = StreamController<PlaybackState>.broadcast();

      when(() => soundPlayer.getPlaybackStateSubscription()).thenAnswer(
        (_) => playbackStates.stream.listen((_) {}),
      );
      when(() => soundPlayer.setLoopMode(any())).thenAnswer((_) async {});
      when(() => soundPlayer.playNewSong(any())).thenAnswer((_) async {});
      when(() => soundPlayer.resumeOrPauseSong()).thenAnswer((_) async {});
      when(() => soundPlayer.stop()).thenAnswer((_) async {});
      when(
        () => soundPlayer.setNotificationSkipHandlers(
          skipToNext: any(named: 'skipToNext'),
          skipToPrevious: any(named: 'skipToPrevious'),
        ),
      ).thenAnswer((invocation) {
        skipToNext =
            invocation.namedArguments[#skipToNext] as NotificationSkipHandler?;
        skipToPrevious = invocation.namedArguments[#skipToPrevious]
            as NotificationSkipHandler?;
      });
      when(() => soundPlayer.setNotificationSkipHandlers()).thenAnswer((_) {});

      soundCollectionManager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );
      viewModel = PlaylistViewModel(
        playlistManager: playlistManager,
        soundCollectionManager: soundCollectionManager,
      );
    });

    tearDown(() async {
      if (!isViewModelDisposed) {
        viewModel.dispose();
      }
      await playbackStates.close();
    });

    test('exposes sorted songs and case-insensitive search state', () async {
      await viewModel.initialize();

      expect(viewModel.songs.map((song) => song.name), [
        'alpha',
        'beta',
        'gamma',
      ]);

      viewModel.setSearchQuery('LPH');

      expect(viewModel.displayedSongs.map((song) => song.name), ['alpha']);

      viewModel.toggleSearch();

      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.isSearchVisible, isTrue);
      expect(viewModel.displayedSongs, hasLength(3));
    });

    test('switches playlists and applies the named playlist loop mode',
        () async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(
        playlistId,
        '/music/beta.mp3',
      );
      await viewModel.initialize();
      clearInteractions(soundPlayer);

      await viewModel.switchPlaylist('Focus');

      expect(viewModel.currentPlaylistName, 'Focus');
      expect(viewModel.songs.map((song) => song.name), ['beta']);
      expect(viewModel.currentSong, isNull);
      expect(viewModel.isPlaybackAvailable, isTrue);
      verify(() => soundPlayer.stop()).called(1);
      verify(() => soundPlayer.setLoopMode(false)).called(1);
    });

    test('switching playlists stops playback and clears the selected song',
        () async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(
        playlistId,
        songs[1].filePath,
      );
      await viewModel.initialize();
      await viewModel.selectSong(songs.first);
      clearInteractions(soundPlayer);

      await viewModel.switchPlaylist('Focus');

      expect(viewModel.currentSong, isNull);
      expect(viewModel.canControlCurrentSong, isFalse);
      verify(() => soundPlayer.stop()).called(1);
      verifyNever(() => soundPlayer.playNewSong(any()));
    });

    test('settings stop playback and block commands until settings closes',
        () async {
      await viewModel.initialize();
      await viewModel.selectSong(songs.first);
      clearInteractions(soundPlayer);

      await viewModel.enterSettings();
      await viewModel.selectSong(songs.last);
      await viewModel.resumeOrPause();
      await viewModel.shuffle();
      await skipToNext!();

      expect(viewModel.isPlaybackAvailable, isFalse);
      expect(viewModel.currentSong, isNull);
      expect(viewModel.canControlCurrentSong, isFalse);
      expect(viewModel.canShuffle, isFalse);
      verify(() => soundPlayer.stop()).called(1);
      verifyNever(() => soundPlayer.playNewSong(any()));
      verifyNever(() => soundPlayer.resumeOrPauseSong());

      viewModel.leaveSettings();

      expect(viewModel.isPlaybackAvailable, isTrue);
      expect(viewModel.currentSong, isNull);
      expect(viewModel.canControlCurrentSong, isFalse);
    });

    test('completed playback advances and wraps when looping is off', () async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      for (final song in songs) {
        await playlistRepository.addSong(playlistId, song.filePath);
      }
      await playlistManager.switchToPlaylist('Focus');
      await viewModel.initialize();
      await viewModel.selectSong(songs.last);
      clearInteractions(soundPlayer);

      playbackStates.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.currentSong, songs.first);
      verify(() => soundPlayer.playNewSong(songs.first)).called(1);
    });

    test('notification handlers navigate and wrap in the current playlist',
        () async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      for (final song in songs) {
        await playlistRepository.addSong(playlistId, song.filePath);
      }
      await playlistManager.switchToPlaylist('Focus');
      await viewModel.initialize();
      await viewModel.selectSong(songs.last);
      clearInteractions(soundPlayer);

      await skipToNext!();
      await skipToPrevious!();

      verify(() => soundPlayer.playNewSong(songs.first)).called(1);
      verify(() => soundPlayer.playNewSong(songs.last)).called(1);
    });

    test('notification commands before song selection are no-ops', () async {
      await viewModel.initialize();
      clearInteractions(soundPlayer);

      await skipToNext!();
      await skipToPrevious!();

      verifyNever(() => soundPlayer.playNewSong(any()));
      expect(viewModel.currentSong, isNull);
    });

    test('completed playback without a selected song is a no-op', () async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(
        playlistId,
        songs.first.filePath,
      );
      await playlistManager.switchToPlaylist('Focus');
      await viewModel.initialize();
      clearInteractions(soundPlayer);

      playbackStates.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => soundPlayer.playNewSong(any()));
      expect(viewModel.currentSong, isNull);
    });

    test('shuffle with no songs is a no-op', () async {
      await playlistRepository.create('Empty');
      await playlistManager.switchToPlaylist('Empty');
      await viewModel.initialize();
      clearInteractions(soundPlayer);

      await viewModel.shuffle();

      expect(viewModel.canShuffle, isFalse);
      expect(viewModel.currentSong, isNull);
      verifyNever(() => soundPlayer.playNewSong(any()));
    });

    test('adds and removes songs through PlaylistManager commands', () async {
      await playlistRepository.create('Focus');
      await viewModel.initialize();

      await viewModel.addSongToPlaylist('Focus', songs.first);
      await viewModel.switchPlaylist('Focus');

      expect(viewModel.songs, [songs.first]);

      final removed =
          await viewModel.removeSongFromCurrentPlaylist(songs.first);

      expect(removed, isTrue);
      expect(viewModel.songs, isEmpty);
    });

    test('dispose removes listeners, cancels playback, and clears handlers',
        () async {
      await viewModel.initialize();
      var notifications = 0;
      viewModel.addListener(() => notifications++);
      clearInteractions(soundPlayer);

      viewModel.dispose();
      isViewModelDisposed = true;
      await playlistManager.switchToPlaylist('All Files');
      playbackStates.add(
        PlaybackState(
          processingState: AudioProcessingState.ready,
          playing: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);
      verify(() => soundPlayer.setNotificationSkipHandlers()).called(1);
    });
  });
}
