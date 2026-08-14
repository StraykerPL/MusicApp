import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_load_status.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/music_library_service.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

class FakeMusicFileRepository extends MusicFileRepository {
  FakeMusicFileRepository(this.songs);

  List<MusicFile> songs;
  int getAllCalls = 0;
  Object? error;
  Completer<void>? pendingLoad;

  @override
  Future<MusicScanResult> getAll(List<String> storageLocations) async {
    getAllCalls++;
    final pending = pendingLoad;
    if (pending != null) {
      await pending.future;
    }
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    return MusicScanResult(
      songs: songs,
      skippedLocations: const <String>[],
    );
  }
}

void main() {
  group('PlaylistViewModel', () {
    late FakePlaylistRepository playlistRepository;
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late PlaylistManager playlistManager;
    late MockSoundPlayer soundPlayer;
    late SoundCollectionManager soundCollectionManager;
    late MusicLibraryService musicLibraryService;
    late FakeMusicFileRepository musicFileRepository;
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
      musicFileRepository = FakeMusicFileRepository(songs);
      musicLibraryService = MusicLibraryService(
        musicFileRepository: musicFileRepository,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );
      viewModel = PlaylistViewModel(
        playlistManager: playlistManager,
        soundCollectionManager: soundCollectionManager,
        musicLibraryService: musicLibraryService,
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

    test('publishes a complete sorted immutable collection atomically',
        () async {
      final observedCollections = <List<String>>[];
      playlistManager.addListener(() {
        observedCollections.add(
          playlistManager.currentPlaylistSongs
              .map((song) => song.name)
              .toList(),
        );
      });

      await viewModel.initialize();

      expect(viewModel.musicLoadStatus, MusicLoadStatus.ready);
      expect(viewModel.allSongs.map((song) => song.name), [
        'alpha',
        'beta',
        'gamma',
      ]);
      expect(observedCollections.single, <String>['alpha', 'beta', 'gamma']);
      expect(
        () => viewModel.allSongs.add(createSong('/music/new.mp3')),
        throwsUnsupportedError,
      );
    });

    test('concurrent initialize calls start only one music scan', () async {
      final pendingLoad = Completer<void>();
      musicFileRepository.pendingLoad = pendingLoad;

      final first = viewModel.initialize();
      final second = viewModel.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(musicFileRepository.getAllCalls, 1);
      expect(viewModel.musicLoadStatus, MusicLoadStatus.loading);
      pendingLoad.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(viewModel.musicLoadStatus, MusicLoadStatus.ready);
    });

    test('failed initial load can retry after the first attempt completes',
        () async {
      final previousOnError = FlutterError.onError;
      final reportedErrors = <FlutterErrorDetails>[];
      FlutterError.onError = reportedErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);
      musicFileRepository.error = StateError('scan failed');

      await viewModel.initialize();

      expect(viewModel.musicLoadStatus, MusicLoadStatus.failed);
      expect(musicFileRepository.getAllCalls, 1);
      musicFileRepository.error = null;
      await viewModel.retryInitialMusicLoad();

      expect(musicFileRepository.getAllCalls, 2);
      expect(viewModel.musicLoadStatus, MusicLoadStatus.ready);
      expect(reportedErrors, hasLength(1));
    });

    test('reconciles the selected song to the newly loaded path instance',
        () async {
      final selected = songs[1];
      await viewModel.selectSong(selected);
      final replacement = createSong(selected.filePath);
      musicFileRepository.songs = <MusicFile>[replacement];

      await viewModel.initialize();

      expect(viewModel.currentSong, same(replacement));
    });

    test('stops and clears selection when its path is no longer loaded',
        () async {
      await viewModel.selectSong(songs[1]);
      musicFileRepository.songs = <MusicFile>[createSong('/music/other.mp3')];
      clearInteractions(soundPlayer);

      await viewModel.initialize();

      expect(viewModel.currentSong, isNull);
      verify(() => soundPlayer.stop()).called(1);
    });

    test('playback source errors are retained at the view-model boundary',
        () async {
      final error = StateError('unreadable');
      when(() => soundPlayer.playNewSong(any())).thenThrow(error);
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = previousOnError);
      await viewModel.initialize();

      await viewModel.selectSong(viewModel.songs.first);

      expect(viewModel.currentSong, isNull);
      expect(viewModel.playbackError, same(error));
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
      await playlistManager.switchToPlaylist(Constants.allFilesListName);
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
