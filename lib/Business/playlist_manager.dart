import 'package:flutter/material.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Models/music_file.dart';

final class PlaylistManager with ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  final List<MusicFile> _allSongs;
  
  String _previousPlaylist = "";
  String _currentPlaylist = "All Files";
  List<String> _availablePlaylists = ["All Files"];
  List<MusicFile> _currentPlaylistSongs = [];

  String get previousPlaylist => _previousPlaylist;
  String get currentPlaylist => _currentPlaylist;
  List<String> get availablePlaylists => _availablePlaylists;
  List<MusicFile> get currentPlaylistSongs => _currentPlaylistSongs;

  PlaylistManager({
    required DatabaseHelper databaseHelper,
    required List<MusicFile> allSongs,
  }) : _databaseHelper = databaseHelper,
       _allSongs = allSongs {
    _currentPlaylistSongs = List.from(_allSongs);
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    return await _databaseHelper.getPlaylists();
  }

  Future<List<Map<String, dynamic>>> getPlaylistSongs(int playlistId) async {
    return await _databaseHelper.getPlaylistSongs(playlistId);
  }

  Future<int> createPlaylist(String playlistName) async {
    final playlistId = await _databaseHelper.createPlaylist(playlistName);
    await loadAvailablePlaylists();
    return playlistId;
  }

  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    await _databaseHelper.addSongToPlaylist(playlistId, songPath);
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    await _databaseHelper.removeSongFromPlaylist(playlistId, songPath);
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _databaseHelper.deletePlaylist(playlistId);
  }

  Future<Map<String, dynamic>?> getPlaylistByName(String playlistName) async {
    final playlists = await getPlaylists();
    try {
      return playlists.firstWhere((p) => p['name'] == playlistName);
    } catch (e) {
      return null;
    }
  }

  Future<List<MusicFile>> getPlaylistSongsByName(String playlistName, List<MusicFile> allSongs) async {
    if (playlistName == "All Files") {
      return List.from(allSongs);
    }

    final playlist = await getPlaylistByName(playlistName);
    if (playlist == null) {
      return List.from(allSongs);
    }

    final playlistSongs = await getPlaylistSongs(playlist['id']);
    final playlistSongPaths = playlistSongs.map((song) => song['songPath'] as String).toList();
    
    return allSongs.where((song) => playlistSongPaths.contains(song.filePath)).toList();
  }

  Future<List<String>> getAllPlaylistNames() async {
    final playlists = await getPlaylists();
    final playlistNames = ["All Files"];
    
    for (final playlist in playlists) {
      playlistNames.add(playlist['name'] as String);
    }

    return playlistNames;
  }

  Future<void> loadAvailablePlaylists() async {
    _availablePlaylists = await getAllPlaylistNames();
  }

  Future<void> switchToPlaylist(String playlistName) async {
    _previousPlaylist = _currentPlaylist;
    _currentPlaylist = playlistName;
    _currentPlaylistSongs = await getPlaylistSongsByName(_currentPlaylist, _allSongs);
    notifyListeners();
  }

  Future<void> refreshCurrentPlaylist() async {
    await switchToPlaylist(_currentPlaylist);
  }

  Future<void> addSongToPlaylistByName(String playlistName, String songPath) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await addSongToPlaylist(playlist['id'], songPath);
      
      if (_currentPlaylist == playlistName) {
        await refreshCurrentPlaylist();
      }
    }
  }

  Future<void> removeSongFromPlaylistByName(String playlistName, String songPath) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await removeSongFromPlaylist(playlist['id'], songPath);
      
      if (_currentPlaylist == playlistName) {
        await refreshCurrentPlaylist();
      }
    }
  }

  Future<void> deletePlaylistByName(String playlistName) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await deletePlaylist(playlist['id']);
      await loadAvailablePlaylists();
      
      if (_currentPlaylist == playlistName) {
        await switchToPlaylist("All Files");
      }
    }
  }

  Future<bool> isSongInPlaylist(String playlistName, String songPath) async {
    if (playlistName == "All Files") {
      return true;
    }
    
    final playlist = await getPlaylistByName(playlistName);
    if (playlist == null) {
      return false;
    }
    
    final playlistSongs = await getPlaylistSongs(playlist['id']);
    return playlistSongs.any((song) => song['songPath'] == songPath);
  }

  Future<List<String>> getPlaylistsContainingSong(String songPath) async {
    final playlists = await getPlaylists();
    final containingPlaylists = <String>[];
    
    for (final playlist in playlists) {
      final isInPlaylist = await isSongInPlaylist(playlist['name'], songPath);
      if (isInPlaylist) {
        containingPlaylists.add(playlist['name']);
      }
    }
    
    return containingPlaylists;
  }
}
