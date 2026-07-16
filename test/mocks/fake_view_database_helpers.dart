import 'dart:async';

import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';

class FakePlaylistDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> _playlists = [];
  final List<Map<String, dynamic>> _playlistSongs = [];

  @override
  Future<int> createPlaylist(String playlistName) async {
    final id = _playlists.length + 1;
    _playlists.add({'id': id, 'name': playlistName});
    return id;
  }

  @override
  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    _playlistSongs.add({'playlistId': playlistId, 'songPath': songPath});
  }

  @override
  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    _playlistSongs.removeWhere(
      (song) =>
          song['playlistId'] == playlistId && song['songPath'] == songPath,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    return List<Map<String, dynamic>>.from(_playlists);
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaylistSongs(int playlistId) async {
    return _playlistSongs
        .where((song) => song['playlistId'] == playlistId)
        .map(Map<String, dynamic>.from)
        .toList();
  }
}

class FakeSettingsDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> settings = [
    {'id': 1, 'name': 'playedSongsMaxAmount', 'value': '0'},
  ];
  final List<Map<String, dynamic>> storageLocations = [
    {'id': 1, 'name': '/storage/emulated/0/Music'},
  ];
  int _nextStorageId = 2;
  final List<Map<String, dynamic>> playlists = [];
  int _nextPlaylistId = 1;
  int getSettingsSnapshotCalls = 0;
  int saveSettingsSnapshotCalls = 0;
  Object? saveSettingsError;
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
  Future<SettingsSnapshot> getSettingsSnapshot() async {
    getSettingsSnapshotCalls++;
    return super.getSettingsSnapshot();
  }

  @override
  Future<void> saveSettingsSnapshot(SettingsSnapshot snapshot) async {
    saveSettingsSnapshotCalls++;
    _saveStarted?.complete();
    _saveStarted = null;
    final pendingSave = _pendingSave;
    if (pendingSave != null) {
      await pendingSave.future;
    }
    final error = saveSettingsError;
    if (error != null) {
      throw error;
    }
    await super.saveSettingsSnapshot(snapshot);
  }

  List<Map<String, dynamic>> _table(String tableName) {
    if (tableName == DatabaseConstants.settingsTableName) {
      return settings;
    }
    if (tableName == DatabaseConstants.storagePathsTableName) {
      return storageLocations;
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllData(String tableName) async {
    return _table(tableName).map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<void> updateDataByName(
    String tableName,
    String name,
    Map<String, dynamic> data,
  ) async {
    _table(tableName).firstWhere((row) => row['name'] == name).addAll(data);
  }

  @override
  Future<void> cleanTable(String tableName) async {
    _table(tableName).clear();
  }

  @override
  Future<void> insertData(
    String tableName,
    List<Map<String, dynamic>> data,
  ) async {
    for (final row in data) {
      _table(tableName).add({
        if (tableName == DatabaseConstants.storagePathsTableName)
          'id': _nextStorageId++,
        ...row,
      });
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPlaylists() async =>
      playlists.map(Map<String, dynamic>.from).toList();

  @override
  Future<int> createPlaylist(String playlistName) async {
    final id = _nextPlaylistId++;
    playlists.add({'id': id, 'name': playlistName});
    return id;
  }

  @override
  Future<void> deletePlaylist(int playlistId) async {
    playlists.removeWhere((playlist) => playlist['id'] == playlistId);
  }
}
