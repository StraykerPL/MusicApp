import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/audio_folder.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

void main() {
  group('SettingsViewModel', () {
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late FakePlaylistRepository playlistRepository;
    late PlaylistManager playlistManager;
    late SettingsViewModel viewModel;

    setUp(() {
      settingsSnapshotRepository = FakeSettingsSnapshotRepository();
      playlistRepository = FakePlaylistRepository();
      playlistManager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: [
          createSong('content://test/audio/music/alpha.mp3'),
          createSong('content://test/audio/music/beta.mp3'),
          createSong('content://test/audio/music/gamma.mp3'),
        ],
      );
      viewModel = SettingsViewModel(
        settingsSnapshotRepository: settingsSnapshotRepository,
        playlistManager: playlistManager,
        loadedSongCount: 3,
        audioFolderLoader: () async => const <AudioFolder>[
          AudioFolder(
            sourceId: 'mediastore://external_primary/Music/',
            displayPath: '/storage/emulated/0/Music',
            volumeName: 'external_primary',
            relativePath: 'Music/',
          ),
          AudioFolder(
            sourceId: 'mediastore://external_primary/Custom/',
            displayPath: '/storage/emulated/0/Custom',
            volumeName: 'external_primary',
            relativePath: 'Custom/',
          ),
        ],
      );
    });

    tearDown(() => viewModel.dispose());

    test('loads settings, storage locations, and playlists', () async {
      await playlistRepository.create('Focus');

      await viewModel.load();

      expect(viewModel.playedSongsMaxAmount, 0);
      expect(viewModel.playedSongsMaxAmountText, '0');
      expect(viewModel.playedSongsMaxAllowed, 2);
      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music'],
      );
      expect(viewModel.playlists.single.name, 'Focus');
    });

    test('clamps loaded and entered shuffle history amounts', () async {
      settingsSnapshotRepository.snapshot = SettingsSnapshot(
        playedSongsMaxAmount: 999,
        storageLocations: settingsSnapshotRepository.snapshot.storageLocations,
      );

      await viewModel.load();

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(settingsSnapshotRepository.snapshot.playedSongsMaxAmount, 2);

      viewModel.setPlayedSongsMaxAmountFromText('999');
      expect(viewModel.playedSongsMaxAmount, 2);
      expect(viewModel.playedSongsMaxAmountText, '2');
    });

    test('accepts only adapter-provided audio folders', () async {
      await viewModel.load();
      final failure = viewModel.addAvailableAudioFolder(99);

      expect(failure, isA<SettingsCommandFailure>());

      expect(
        viewModel.addAvailableAudioFolder(1),
        isA<SettingsCommandSuccess>(),
      );
      viewModel.selectStorageLocation(1);
      viewModel.removeSelectedStoragePath();

      expect(viewModel.storageLocationDisplayPaths, [
        'Music',
      ]);
      expect(viewModel.selectedStorageLocationIndex, isNull);
    });

    test('validates duplicate playlists and creates and deletes selection',
        () async {
      await viewModel.load();

      expect(
        await viewModel.createPlaylist('Focus'),
        isA<SettingsCommandSuccess>(),
      );
      final duplicate = await viewModel.createPlaylist('Focus');
      expect(duplicate, isA<SettingsCommandFailure>());
      expect(
        (duplicate as SettingsCommandFailure).message,
        'Playlist "Focus" already exists!',
      );

      viewModel.selectPlaylist('Focus');
      expect(
        await viewModel.deleteSelectedPlaylist(),
        isA<SettingsCommandSuccess>(),
      );
      expect(viewModel.playlists, isEmpty);
      expect(viewModel.selectedPlaylistName, isNull);
    });

    test('save persists state and defaults persist immediately', () async {
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addAvailableAudioFolder(1);

      await viewModel.save();

      expect(settingsSnapshotRepository.snapshot.playedSongsMaxAmount, 2);
      expect(
        settingsSnapshotRepository.snapshot.storageLocations,
        [
          'mediastore://external_primary/Music/',
          'mediastore://external_primary/Custom/',
        ],
      );

      await viewModel.restoreDefaults();

      expect(viewModel.playedSongsMaxAmount, 0);
      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music'],
      );
      expect(settingsSnapshotRepository.snapshot.playedSongsMaxAmount, 0);
      expect(
        settingsSnapshotRepository.snapshot.storageLocations,
        ['mediastore://external_primary/Music/'],
      );
    });

    test('save reports persistence failure and clears busy state', () async {
      settingsSnapshotRepository.saveError = StateError('disk full');

      final result = await viewModel.save();

      expect(result, isA<SettingsCommandFailure>());
      expect(
        (result as SettingsCommandFailure).message,
        contains('disk full'),
      );
      expect(viewModel.isPersistenceInProgress, isFalse);
    });

    test('restore defaults reports persistence failure and keeps defaults',
        () async {
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addAvailableAudioFolder(1);
      settingsSnapshotRepository.saveError = StateError('read-only');

      final result = await viewModel.restoreDefaults();

      expect(result, isA<SettingsCommandFailure>());
      expect(
        (result as SettingsCommandFailure).message,
        'Failed to restore defaults: Bad state: read-only',
      );
      expect(viewModel.playedSongsMaxAmount, 0);
      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music'],
      );
      expect(viewModel.isPersistenceInProgress, isFalse);
    });

    test('a second persistence command is rejected while save is running',
        () async {
      final saveStarted = settingsSnapshotRepository.pauseNextSave();
      final firstSave = viewModel.save();
      await saveStarted;

      expect(viewModel.isPersistenceInProgress, isTrue);
      expect(
        await viewModel.restoreDefaults(),
        isA<SettingsCommandNoChange>(),
      );

      settingsSnapshotRepository.completeSave();
      expect(await firstSave, isA<SettingsCommandSuccess>());
      expect(viewModel.isPersistenceInProgress, isFalse);
    });

    test('load replaces local storage paths from the persisted snapshot',
        () async {
      await viewModel.load();
      viewModel.addAvailableAudioFolder(1);

      await viewModel.load();

      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music'],
      );
    });

    test('playlist creation preserves unsaved settings edits', () async {
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addAvailableAudioFolder(1);

      await viewModel.createPlaylist('Focus');

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music', 'Custom'],
      );
      expect(viewModel.playlists.single.name, 'Focus');
    });

    test('playlist deletion preserves unsaved settings edits', () async {
      await playlistRepository.create('Focus');
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addAvailableAudioFolder(1);
      viewModel.selectPlaylist('Focus');

      await viewModel.deleteSelectedPlaylist();

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(
        viewModel.storageLocationDisplayPaths,
        ['Music', 'Custom'],
      );
      expect(viewModel.playlists, isEmpty);
      expect(viewModel.selectedPlaylistName, isNull);
    });
  });
}
