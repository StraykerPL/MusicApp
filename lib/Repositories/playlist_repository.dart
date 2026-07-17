import 'package:strayker_music/Models/playlist.dart';
import 'package:strayker_music/Services/database_helper.dart';

class PlaylistRepository {
  PlaylistRepository({required DatabaseHelper databaseHelper})
      : _databaseHelper = databaseHelper;

  final DatabaseHelper _databaseHelper;

  Future<List<Playlist>> getAll() async {
    return _mapRows(await _databaseHelper.queryPlaylists());
  }

  Future<Playlist?> getByName(String name) async {
    final row = await _databaseHelper.queryPlaylistByName(name);
    return row == null ? null : _mapRow(row);
  }

  Future<Playlist> create(String name) async {
    final id = await _databaseHelper.insertPlaylist(name);
    return Playlist(id: id, name: name);
  }

  Future<void> delete(int playlistId) {
    return _databaseHelper.deletePlaylist(playlistId);
  }

  Future<List<String>> getSongPaths(int playlistId) {
    return _databaseHelper.queryPlaylistSongPaths(playlistId);
  }

  Future<void> addSong(int playlistId, String songPath) {
    return _databaseHelper.insertPlaylistSong(playlistId, songPath);
  }

  Future<void> removeSong(int playlistId, String songPath) {
    return _databaseHelper.deletePlaylistSong(playlistId, songPath);
  }

  Future<bool> containsSong(int playlistId, String songPath) {
    return _databaseHelper.queryPlaylistContainsSong(playlistId, songPath);
  }

  Future<List<Playlist>> getContainingSong(String songPath) async {
    return _mapRows(
      await _databaseHelper.queryPlaylistsContainingSong(songPath),
    );
  }

  List<Playlist> _mapRows(List<Map<String, Object?>> rows) =>
      [for (final row in rows) _mapRow(row)];

  Playlist _mapRow(Map<String, Object?> row) => Playlist(
        id: row['id'] as int,
        name: row['name'] as String,
      );
}
