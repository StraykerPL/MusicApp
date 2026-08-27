import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:strayker_media_store/strayker_media_store.dart';
import 'package:strayker_music/Services/database_helper.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Shared/input_security.dart';

typedef AudioFolderLoader = Future<List<AudioFolder>> Function();

sealed class SettingsCommandResult {
  const SettingsCommandResult();
}

final class SettingsCommandSuccess extends SettingsCommandResult {
  const SettingsCommandSuccess();
}

final class SettingsCommandNoChange extends SettingsCommandResult {
  const SettingsCommandNoChange();
}

final class SettingsCommandFailure extends SettingsCommandResult {
  const SettingsCommandFailure(this.message);

  final String message;
}

final class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    required SettingsSnapshotRepository settingsSnapshotRepository,
    required PlaylistManager playlistManager,
    required int loadedSongCount,
    AudioFolderLoader? audioFolderLoader,
  })  : _settingsSnapshotRepository = settingsSnapshotRepository,
        _playlistManager = playlistManager,
        _audioFolderLoader =
            audioFolderLoader ?? const StraykerMediaStore().listAudioFolders,
        playedSongsMaxAllowed = loadedSongCount > 1 ? loadedSongCount - 1 : 0;

  final SettingsSnapshotRepository _settingsSnapshotRepository;
  final PlaylistManager _playlistManager;
  final AudioFolderLoader _audioFolderLoader;

  int _playedSongsMaxAmount = 0;
  String _playedSongsMaxAmountText = '';
  List<AudioFolder> _storageLocations = [];
  List<AudioFolder> _availableAudioFolders = [];
  String? _selectedStorageSourceId;
  List<Playlist> _playlists = [];
  String? _selectedPlaylistName;
  bool _isPersistenceInProgress = false;
  bool _disposed = false;

  int get playedSongsMaxAmount => _playedSongsMaxAmount;
  final int playedSongsMaxAllowed;
  String get playedSongsMaxAmountText => _playedSongsMaxAmountText;
  UnmodifiableListView<String> get storageLocationDisplayPaths =>
      UnmodifiableListView(
        _storageLocations.map((folder) => folder.displayPath
            .substring(folder.displayPath.lastIndexOf('/') + 1)),
      );
  UnmodifiableListView<String> get availableAudioFolderDisplayPaths =>
      UnmodifiableListView(
        _availableAudioFolders.map((folder) => folder.displayPath
            .substring(folder.displayPath.lastIndexOf('/') + 1)),
      );
  int? get selectedStorageLocationIndex {
    final sourceId = _selectedStorageSourceId;

    if (sourceId == null) return null;
    final index = _storageLocations.indexWhere(
      (folder) => folder.sourceId == sourceId,
    );

    return index < 0 ? null : index;
  }

  UnmodifiableListView<Playlist> get playlists =>
      UnmodifiableListView(_playlists);
  String? get selectedPlaylistName => _selectedPlaylistName;
  bool get isPersistenceInProgress => _isPersistenceInProgress;

  /// Replaces local state from persistence during initial route loading.
  Future<void> load() async {
    final snapshot = await _settingsSnapshotRepository.get();
    final savedAmount = snapshot.playedSongsMaxAmount;
    _setPlayedSongsMaxAmount(savedAmount);

    if (_playedSongsMaxAmount != savedAmount) {
      await _settingsSnapshotRepository.updatePlayedSongsMaxAmount(
        _playedSongsMaxAmount,
      );
    }

    try {
      _availableAudioFolders = await _audioFolderLoader();
    } on Object {
      _availableAudioFolders = [];
    }

    final foldersById = <String, AudioFolder>{
      for (final folder in _availableAudioFolders) folder.sourceId: folder,
    };
    _storageLocations = snapshot.storageLocations
        .map((sourceId) =>
            foldersById[sourceId] ?? _folderFromSourceId(sourceId))
        .whereType<AudioFolder>()
        .toList();
    _selectedStorageSourceId = null;
    await _refreshPlaylists();
    _selectedPlaylistName = null;
    _notifyListeners();
  }

  void setPlayedSongsMaxAmountFromText(String value) {
    final parsedValue = int.tryParse(value) ?? 0;
    final clampedValue = _clampPlayedSongsMaxAmount(parsedValue);
    _playedSongsMaxAmount = clampedValue;
    _playedSongsMaxAmountText =
        clampedValue == parsedValue ? value : clampedValue.toString();
    _notifyListeners();
  }

  void selectStorageLocation(int? index) {
    _selectedStorageSourceId = index == null
        ? null
        : _storageLocations.elementAtOrNull(index)?.sourceId;
    _notifyListeners();
  }

  SettingsCommandResult addAvailableAudioFolder(int index) {
    final folder = _availableAudioFolders.elementAtOrNull(index);

    if (folder == null) {
      return const SettingsCommandFailure(
          'The selected audio folder is unavailable.');
    }

    if (!_storageLocations.any((item) => item.sourceId == folder.sourceId)) {
      _storageLocations.add(folder);
      _notifyListeners();
    }

    return const SettingsCommandSuccess();
  }

  void removeSelectedStoragePath() {
    _storageLocations.removeWhere(
      (folder) => folder.sourceId == _selectedStorageSourceId,
    );
    _selectedStorageSourceId = null;
    _notifyListeners();
  }

  void selectPlaylist(String? name) {
    _selectedPlaylistName = name;
    _notifyListeners();
  }

  Future<SettingsCommandResult> createPlaylist(String name) async {
    if (name.trim().isEmpty) {
      return const SettingsCommandNoChange();
    }

    final playlistName = name.trim();
    final validationError = InputSecurity.getValidationError(playlistName);
    if (validationError != null) {
      return SettingsCommandFailure(validationError);
    }

    if (_playlists.any((playlist) => playlist.name == playlistName)) {
      return SettingsCommandFailure(
        'Playlist "$playlistName" already exists!',
      );
    }

    try {
      await _playlistManager.createPlaylist(playlistName);
      await _refreshPlaylists();
      _notifyListeners();
      return const SettingsCommandSuccess();
    } catch (error) {
      return SettingsCommandFailure('Failed to create playlist: $error');
    }
  }

  Future<SettingsCommandResult> deleteSelectedPlaylist() async {
    if (_selectedPlaylistName == null) {
      return const SettingsCommandNoChange();
    }

    final playlist = _playlists.firstWhere(
      (candidate) => candidate.name == _selectedPlaylistName,
      orElse: () => const Playlist(id: -1, name: ''),
    );
    if (playlist.id == -1) {
      return const SettingsCommandNoChange();
    }

    try {
      await _playlistManager.deletePlaylistByName(playlist.name);
      _selectedPlaylistName = null;
      await _refreshPlaylists();
      _notifyListeners();
      return const SettingsCommandSuccess();
    } catch (error) {
      return SettingsCommandFailure('Failed to delete playlist: $error');
    }
  }

  Future<SettingsCommandResult> save() async {
    if (_isPersistenceInProgress) {
      return const SettingsCommandNoChange();
    }

    _setPersistenceInProgress(true);
    try {
      _setPlayedSongsMaxAmount(_playedSongsMaxAmount);
      _notifyListeners();
      await _persistCurrentSettings();
      return const SettingsCommandSuccess();
    } catch (error) {
      return SettingsCommandFailure('Failed to save settings: $error');
    } finally {
      _setPersistenceInProgress(false);
    }
  }

  Future<SettingsCommandResult> restoreDefaults() async {
    if (_isPersistenceInProgress) {
      return const SettingsCommandNoChange();
    }

    _setPersistenceInProgress(true);
    try {
      _playedSongsMaxAmount = DatabaseHelper.getPlayedSongsMaxAmountDefault();
      _playedSongsMaxAmountText = _playedSongsMaxAmount.toString();
      _storageLocations = DatabaseHelper.getSoundStorageLocationsDefault()
          .map(_folderFromSourceId)
          .whereType<AudioFolder>()
          .toList();
      _selectedStorageSourceId = null;
      _notifyListeners();
      await _persistCurrentSettings();
      return const SettingsCommandSuccess();
    } catch (error) {
      return SettingsCommandFailure('Failed to restore defaults: $error');
    } finally {
      _setPersistenceInProgress(false);
    }
  }

  Future<void> _refreshPlaylists() async {
    _playlists = await _playlistManager.getPlaylists();
  }

  Future<void> _persistCurrentSettings() {
    return _settingsSnapshotRepository.save(
      SettingsSnapshot(
        playedSongsMaxAmount: _playedSongsMaxAmount,
        storageLocations:
            _storageLocations.map((folder) => folder.sourceId).toList(),
      ),
    );
  }

  void _setPersistenceInProgress(bool value) {
    _isPersistenceInProgress = value;
    _notifyListeners();
  }

  int _clampPlayedSongsMaxAmount(int value) {
    return value.clamp(0, playedSongsMaxAllowed);
  }

  void _setPlayedSongsMaxAmount(int value) {
    _playedSongsMaxAmount = _clampPlayedSongsMaxAmount(value);
    _playedSongsMaxAmountText = _playedSongsMaxAmount.toString();
  }

  static AudioFolder? _folderFromSourceId(String sourceId) {
    final match = RegExp(r'^mediastore://([^/?#]+)/((?:[^/?#]+/)+)$')
        .firstMatch(sourceId);

    if (match == null) return null;

    try {
      final volume = Uri.decodeComponent(match.group(1)!);
      final segments = match
          .group(2)!
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .map(Uri.decodeComponent)
          .toList();

      if (segments.isEmpty ||
          segments.any((segment) =>
              segment.isEmpty ||
              segment == '.' ||
              segment == '..' ||
              segment.contains('/'))) {
        return null;
      }

      final canonical =
          'mediastore://${Uri.encodeComponent(volume)}/${segments.map(Uri.encodeComponent).join('/')}/';

      if (canonical != sourceId) return null;

      final relativePath = '${segments.join('/')}/';
      final root = volume == 'external_primary'
          ? '/storage/emulated/0'
          : '/storage/$volume';

      return AudioFolder(
        sourceId: sourceId,
        displayPath: '$root/${segments.join('/')}',
        volumeName: volume,
        relativePath: relativePath,
      );
    } on FormatException {
      return null;
    }
  }

  void _notifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
