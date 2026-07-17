import 'dart:async';

import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/playlist_repository.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Services/database_helper.dart';

class FakePlaylistRepository extends PlaylistRepository {
  FakePlaylistRepository() : super(databaseHelper: DatabaseHelper());

  final List<Playlist> _playlists = [];
  final Map<int, List<String>> _songPaths = {};
  int _nextId = 1;

  @override
  Future<List<Playlist>> getAll() async => List<Playlist>.of(_playlists);

  @override
  Future<Playlist?> getByName(String name) async {
    for (final playlist in _playlists) {
      if (playlist.name == name) {
        return playlist;
      }
    }
    return null;
  }

  @override
  Future<Playlist> create(String name) async {
    final playlist = Playlist(id: _nextId++, name: name);
    _playlists.add(playlist);
    _songPaths[playlist.id] = [];
    return playlist;
  }

  @override
  Future<void> delete(int playlistId) async {
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    _songPaths.remove(playlistId);
  }

  @override
  Future<List<String>> getSongPaths(int playlistId) async =>
      List<String>.of(_songPaths[playlistId] ?? const []);

  @override
  Future<void> addSong(int playlistId, String songPath) async {
    _songPaths.putIfAbsent(playlistId, () => []).add(songPath);
  }

  @override
  Future<void> removeSong(int playlistId, String songPath) async {
    _songPaths[playlistId]?.remove(songPath);
  }

  @override
  Future<bool> containsSong(int playlistId, String songPath) async =>
      _songPaths[playlistId]?.contains(songPath) ?? false;

  @override
  Future<List<Playlist>> getContainingSong(String songPath) async => [
        for (final playlist in _playlists)
          if (_songPaths[playlist.id]?.contains(songPath) ?? false) playlist,
      ];
}

class FakeSettingsSnapshotRepository extends SettingsSnapshotRepository {
  FakeSettingsSnapshotRepository()
      : snapshot = SettingsSnapshot(
          playedSongsMaxAmount: 0,
          storageLocations: ['/storage/emulated/0/Music'],
        ),
        super(databaseHelper: DatabaseHelper());

  SettingsSnapshot snapshot;
  int getCalls = 0;
  int saveCalls = 0;
  Object? saveError;
  Completer<void>? _saveStarted;
  Completer<void>? _pendingSave;

  Future<void> pauseNextSave() {
    _saveStarted = Completer<void>();
    _pendingSave = Completer<void>();
    return _saveStarted!.future;
  }

  void completeSave() {
    _pendingSave?.complete();
    _pendingSave = null;
  }

  @override
  Future<SettingsSnapshot> get() async {
    getCalls++;
    return snapshot;
  }

  @override
  Future<void> save(SettingsSnapshot value) async {
    saveCalls++;
    _saveStarted?.complete();
    _saveStarted = null;
    final pendingSave = _pendingSave;
    if (pendingSave != null) {
      await pendingSave.future;
    }
    final error = saveError;
    if (error != null) {
      throw error;
    }
    snapshot = SettingsSnapshot(
      playedSongsMaxAmount: value.playedSongsMaxAmount,
      storageLocations: value.storageLocations,
    );
  }

  @override
  Future<void> updatePlayedSongsMaxAmount(int value) async {
    snapshot = SettingsSnapshot(
      playedSongsMaxAmount: value,
      storageLocations: snapshot.storageLocations,
    );
  }
}
