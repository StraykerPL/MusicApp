import 'package:flutter/material.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Repositories/playlist_repository.dart';

final class PlaylistManager with ChangeNotifier {
  final PlaylistRepository _playlistRepository;
  final List<MusicFile> _allSongs;

  String _currentPlaylist = "All Files";
  List<String> _availablePlaylists = ["All Files"];
  List<MusicFile> _currentPlaylistSongs = [];

  String get currentPlaylist => _currentPlaylist;
  List<String> get availablePlaylists => _availablePlaylists;
  List<MusicFile> get currentPlaylistSongs => _currentPlaylistSongs;

  PlaylistManager({
    required PlaylistRepository playlistRepository,
    required List<MusicFile> allSongs,
  })  : _playlistRepository = playlistRepository,
        _allSongs = allSongs {
    _allSongs.sort(
        (firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
    _currentPlaylistSongs = List.from(_allSongs);
  }

  Future<List<Playlist>> getPlaylists() async {
    return _playlistRepository.getAll();
  }

  Future<List<String>> getPlaylistSongs(int playlistId) async {
    return _playlistRepository.getSongPaths(playlistId);
  }

  Future<int> createPlaylist(String playlistName) async {
    final playlist = await _playlistRepository.create(playlistName);
    await loadAvailablePlaylists();
    notifyListeners();
    return playlist.id;
  }

  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    await _playlistRepository.addSong(playlistId, songPath);
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    await _playlistRepository.removeSong(playlistId, songPath);
  }

  Future<void> deletePlaylist(int playlistId) async {
    await _playlistRepository.delete(playlistId);
    await loadAvailablePlaylists();
    notifyListeners();
  }

  Future<Playlist?> getPlaylistByName(String playlistName) async {
    return _playlistRepository.getByName(playlistName);
  }

  Future<List<MusicFile>> getPlaylistSongsByName(
      String playlistName, List<MusicFile> allSongs) async {
    if (playlistName == "All Files") {
      return List.from(allSongs);
    }

    final playlist = await getPlaylistByName(playlistName);
    if (playlist == null) {
      return List.from(allSongs);
    }

    final playlistSongPaths = await getPlaylistSongs(playlist.id);

    return allSongs
        .where((song) => playlistSongPaths.contains(song.filePath))
        .toList();
  }

  Future<List<String>> getAllPlaylistNames() async {
    final playlists = await getPlaylists();
    final playlistNames = ["All Files"];

    for (final playlist in playlists) {
      playlistNames.add(playlist.name);
    }

    return playlistNames;
  }

  Future<void> loadAvailablePlaylists() async {
    _availablePlaylists = await getAllPlaylistNames();
  }

  Future<void> switchToPlaylist(String playlistName) async {
    _currentPlaylist = playlistName;
    _currentPlaylistSongs =
        await getPlaylistSongsByName(_currentPlaylist, _allSongs);
    notifyListeners();
  }

  Future<void> refreshCurrentPlaylist() async {
    await switchToPlaylist(_currentPlaylist);
  }

  Future<void> addSongToPlaylistByName(
      String playlistName, String songPath) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await addSongToPlaylist(playlist.id, songPath);

      if (_currentPlaylist == playlistName) {
        await refreshCurrentPlaylist();
      }
    }
  }

  Future<void> removeSongFromPlaylistByName(
      String playlistName, String songPath) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await removeSongFromPlaylist(playlist.id, songPath);

      if (_currentPlaylist == playlistName) {
        await refreshCurrentPlaylist();
      }
    }
  }

  Future<void> deletePlaylistByName(String playlistName) async {
    final playlist = await getPlaylistByName(playlistName);
    if (playlist != null) {
      await deletePlaylist(playlist.id);
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

    return _playlistRepository.containsSong(playlist.id, songPath);
  }

  Future<List<String>> getPlaylistsContainingSong(String songPath) async {
    final playlists = await _playlistRepository.getContainingSong(songPath);
    return [for (final playlist in playlists) playlist.name];
  }

  MusicFile getNextSongFromPlaylist(MusicFile song) {
    var index = currentPlaylistSongs.indexOf(song);

    if (++index == currentPlaylistSongs.length) {
      return currentPlaylistSongs[0];
    }

    return currentPlaylistSongs[index++];
  }

  MusicFile getPreviousSongFromPlaylist(MusicFile song) {
    var index = currentPlaylistSongs.indexOf(song);

    if (--index < 0) {
      return currentPlaylistSongs[currentPlaylistSongs.length - 1];
    }

    return currentPlaylistSongs[index];
  }
}
