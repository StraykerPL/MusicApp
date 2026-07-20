import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:strayker_music/Services/database_helper.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Shared/input_security.dart';
import 'package:strayker_music/Shared/storage_path_policy.dart';

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
  })  : _settingsSnapshotRepository = settingsSnapshotRepository,
        _playlistManager = playlistManager,
        playedSongsMaxAllowed = loadedSongCount > 1 ? loadedSongCount - 1 : 0;

  final SettingsSnapshotRepository _settingsSnapshotRepository;
  final PlaylistManager _playlistManager;

  int _playedSongsMaxAmount = 0;
  String _playedSongsMaxAmountText = '';
  List<String> _storageLocations = [];
  String? _selectedStoragePath;
  List<Playlist> _playlists = [];
  String? _selectedPlaylistName;
  bool _isPersistenceInProgress = false;
  bool _disposed = false;

  int get playedSongsMaxAmount => _playedSongsMaxAmount;
  final int playedSongsMaxAllowed;
  String get playedSongsMaxAmountText => _playedSongsMaxAmountText;
  UnmodifiableListView<String> get storageLocations =>
      UnmodifiableListView(_storageLocations);
  String? get selectedStoragePath => _selectedStoragePath;
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

    _storageLocations = List<String>.of(snapshot.storageLocations);
    _selectedStoragePath = null;
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

  void selectStoragePath(String? path) {
    _selectedStoragePath = path;
    _notifyListeners();
  }

  SettingsCommandResult addStoragePath(String path) {
    final validationError = StoragePathPolicy.getValidationError(path);
    if (validationError != null) {
      return SettingsCommandFailure(validationError);
    }

    if (!_storageLocations.contains(path)) {
      _storageLocations.add(path);
      _notifyListeners();
    }
    return const SettingsCommandSuccess();
  }

  void removeSelectedStoragePath() {
    _storageLocations.remove(_selectedStoragePath);
    _selectedStoragePath = null;
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
      _storageLocations = DatabaseHelper.getSoundStorageLocationsDefault();
      _selectedStoragePath = null;
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
        storageLocations: List<String>.of(_storageLocations),
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
