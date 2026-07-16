import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';

import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

void main() {
  group('SettingsViewModel', () {
    late FakeSettingsDatabaseHelper databaseHelper;
    late PlaylistManager playlistManager;
    late SettingsViewModel viewModel;

    setUp(() {
      databaseHelper = FakeSettingsDatabaseHelper();
      playlistManager = PlaylistManager(
        databaseHelper: databaseHelper,
        allSongs: [
          createSong('/music/alpha.mp3'),
          createSong('/music/beta.mp3'),
          createSong('/music/gamma.mp3'),
        ],
      );
      viewModel = SettingsViewModel(
        databaseHelper: databaseHelper,
        playlistManager: playlistManager,
        loadedSongCount: 3,
      );
    });

    tearDown(() => viewModel.dispose());

    test('loads settings, storage locations, and playlists', () async {
      await databaseHelper.createPlaylist('Focus');

      await viewModel.load();

      expect(viewModel.playedSongsMaxAmount, 0);
      expect(viewModel.playedSongsMaxAmountText, '0');
      expect(viewModel.playedSongsMaxAllowed, 2);
      expect(
        viewModel.storageLocations,
        ['/storage/emulated/0/Music'],
      );
      expect(viewModel.playlists.single.name, 'Focus');
    });

    test('clamps loaded and entered shuffle history amounts', () async {
      await databaseHelper.updateDataByName(
        DatabaseConstants.settingsTableName,
        DatabaseConstants.playedSongsMaxAmountTableValueName,
        {'value': '999'},
      );

      await viewModel.load();

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(databaseHelper.settings.single['value'], 2);

      viewModel.setPlayedSongsMaxAmountFromText('999');
      expect(viewModel.playedSongsMaxAmount, 2);
      expect(viewModel.playedSongsMaxAmountText, '2');
    });

    test('validates and mutates storage paths', () {
      final failure = viewModel.addStoragePath('/storage/emulated/0/Android');

      expect(failure, isA<SettingsCommandFailure>());
      expect(
        (failure as SettingsCommandFailure).message,
        'This folder is restricted by the system. Select a media folder such as Music, Download, or another folder outside Android.',
      );

      expect(
        viewModel.addStoragePath('/music/custom'),
        isA<SettingsCommandSuccess>(),
      );
      viewModel.selectStoragePath('/music/custom');
      viewModel.removeSelectedStoragePath();

      expect(viewModel.storageLocations, isEmpty);
      expect(viewModel.selectedStoragePath, isNull);
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
      viewModel.addStoragePath('/music/custom');

      await viewModel.save();

      expect(databaseHelper.settings.single['value'], 2);
      expect(
        databaseHelper.storageLocations.map((row) => row['name']),
        ['/storage/emulated/0/Music', '/music/custom'],
      );

      await viewModel.restoreDefaults();

      expect(viewModel.playedSongsMaxAmount, 0);
      expect(viewModel.storageLocations, ['/storage/emulated/0/Music']);
      expect(databaseHelper.settings.single['value'], 0);
      expect(
        databaseHelper.storageLocations.map((row) => row['name']),
        ['/storage/emulated/0/Music'],
      );
    });

    test('save reports persistence failure and clears busy state', () async {
      databaseHelper.saveSettingsError = StateError('disk full');

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
      viewModel.addStoragePath('/music/custom');
      databaseHelper.saveSettingsError = StateError('read-only');

      final result = await viewModel.restoreDefaults();

      expect(result, isA<SettingsCommandFailure>());
      expect(
        (result as SettingsCommandFailure).message,
        'Failed to restore defaults: Bad state: read-only',
      );
      expect(viewModel.playedSongsMaxAmount, 0);
      expect(viewModel.storageLocations, ['/storage/emulated/0/Music']);
      expect(viewModel.isPersistenceInProgress, isFalse);
    });

    test('a second persistence command is rejected while save is running',
        () async {
      final saveStarted = databaseHelper.pauseNextSave();
      final firstSave = viewModel.save();
      await saveStarted;

      expect(viewModel.isPersistenceInProgress, isTrue);
      expect(
        await viewModel.restoreDefaults(),
        isA<SettingsCommandNoChange>(),
      );

      databaseHelper.completeSave();
      expect(await firstSave, isA<SettingsCommandSuccess>());
      expect(viewModel.isPersistenceInProgress, isFalse);
    });

    test('load replaces local storage paths from the persisted snapshot',
        () async {
      await viewModel.load();
      viewModel.addStoragePath('/music/unsaved');

      await viewModel.load();

      expect(viewModel.storageLocations, ['/storage/emulated/0/Music']);
    });

    test('playlist creation preserves unsaved settings edits', () async {
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addStoragePath('/music/unsaved');

      await viewModel.createPlaylist('Focus');

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(
        viewModel.storageLocations,
        ['/storage/emulated/0/Music', '/music/unsaved'],
      );
      expect(viewModel.playlists.single.name, 'Focus');
    });

    test('playlist deletion preserves unsaved settings edits', () async {
      await databaseHelper.createPlaylist('Focus');
      await viewModel.load();
      viewModel.setPlayedSongsMaxAmountFromText('2');
      viewModel.addStoragePath('/music/unsaved');
      viewModel.selectPlaylist('Focus');

      await viewModel.deleteSelectedPlaylist();

      expect(viewModel.playedSongsMaxAmount, 2);
      expect(
        viewModel.storageLocations,
        ['/storage/emulated/0/Music', '/music/unsaved'],
      );
      expect(viewModel.playlists, isEmpty);
      expect(viewModel.selectedPlaylistName, isNull);
    });
  });
}
