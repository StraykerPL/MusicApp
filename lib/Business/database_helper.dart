import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

typedef DatabaseProvider = Future<Database> Function();

class DatabaseHelper {
  static const _databaseName = 'strayker_music.db';

  DatabaseHelper({DatabaseProvider? databaseProvider}) : _databaseProvider = databaseProvider ?? _openDatabase;

  final DatabaseProvider _databaseProvider;

  static Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_databaseName';

    return openDatabase(path, version: 1, singleInstance: true, onCreate: (db, version) {
      db.execute('''
        CREATE TABLE settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          value TEXT
        )
      ''');
      db.execute('''
        CREATE TABLE storageLocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT
        )
      ''');
      db.execute('''
        CREATE TABLE playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE
        )
      ''');
      db.execute('''
        CREATE TABLE playlistSongs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          playlistId INTEGER,
          songPath TEXT,
          FOREIGN KEY (playlistId) REFERENCES playlists (id)
        )
      ''');
      db.execute('''
        INSERT INTO settings VALUES (null, "playedSongsMaxAmount", 0)
      ''');
      db.execute('''
        INSERT INTO storageLocations VALUES (null, "/storage/emulated/0/Music")
      ''');

      if (kDebugMode) {
        db.execute('''
          INSERT INTO playlists VALUES (null, "Playlist 1")
        ''');
        db.execute('''
          INSERT INTO playlists VALUES (null, "Playlist 2")
        ''');
        db.execute('''
          INSERT INTO playlists VALUES (null, "Playlist 3")
        ''');
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllData(String tableName) async {
    final db = await _databaseProvider();

    return db.query(tableName);
  }

  Future<void> insertData(String tableName, List<Map<String, dynamic>> data) async {
    final db = await _databaseProvider();

    for (var row in data) {
      await db.insert(tableName, row);
    }
  }

  Future<void> updateData(String tableName, Map<String, dynamic> data) async {
    final db = await _databaseProvider();

    await db.update(tableName, data);
  }

  Future<void> updateDataByName(String tableName, String name, Map<String, dynamic> data) async {
    final db = await _databaseProvider();

    await db.update(tableName, data, where: 'name = ?', whereArgs: [name]);
  }

  Future<void> cleanTable(String tableName) async {
    final db = await _databaseProvider();

    await db.delete(tableName);
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await _databaseProvider();
    return db.query('playlists');
  }

  Future<List<Map<String, dynamic>>> getPlaylistSongs(int playlistId) async {
    final db = await _databaseProvider();
    return db.query('playlistSongs', where: 'playlistId = ?', whereArgs: [playlistId]);
  }

  Future<int> createPlaylist(String playlistName) async {
    final db = await _databaseProvider();
    return await db.insert('playlists', {'name': playlistName});
  }

  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    final db = await _databaseProvider();
    await db.insert('playlistSongs', {'playlistId': playlistId, 'songPath': songPath});
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    final db = await _databaseProvider();
    await db.delete('playlistSongs', where: 'playlistId = ? AND songPath = ?', whereArgs: [playlistId, songPath]);
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await _databaseProvider();
    await db.delete('playlistSongs', where: 'playlistId = ?', whereArgs: [playlistId]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }
}
