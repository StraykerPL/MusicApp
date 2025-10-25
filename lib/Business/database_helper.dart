import 'package:sqflite/sqflite.dart';

final class DatabaseHelper {
  static const _databaseName = 'strayker_music.db';

  static Future<Database> _getDatabase() async {
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
      // Only for debugging.
      // db.execute('''
      //   INSERT INTO playlists VALUES (null, "Playlist 1")
      // ''');
      // db.execute('''
      //   INSERT INTO playlists VALUES (null, "Playlist 2")
      // ''');
      // db.execute('''
      //   INSERT INTO playlists VALUES (null, "Playlist 3")
      // ''');
    });
  }

  Future<List<Map<String, dynamic>>> getAllData(String tableName) async {
    final db = await _getDatabase();

    return db.query(tableName);
  }

  Future<void> insertData(String tableName, List<Map<String, dynamic>> data) async {
    final db = await _getDatabase();

    for (var row in data) {
      await db.insert(tableName, row);
    }
  }

  Future<void> updateData(String tableName, Map<String, dynamic> data) async {
    final db = await _getDatabase();

    await db.update(tableName, data);
  }

  Future<void> updateDataByName(String tableName, String name, Map<String, dynamic> data) async {
    final db = await _getDatabase();

    await db.update(tableName, where: "name = ?", whereArgs: [name], data);
  }

  Future<void> cleanTable(String tableName) async {
    final db = await _getDatabase();

    await db.delete(tableName);
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await _getDatabase();
    return db.query('playlists');
  }

  Future<List<Map<String, dynamic>>> getPlaylistSongs(int playlistId) async {
    final db = await _getDatabase();
    return db.query('playlistSongs', where: 'playlistId = ?', whereArgs: [playlistId]);
  }

  Future<int> createPlaylist(String playlistName) async {
    final db = await _getDatabase();
    return await db.insert('playlists', {'name': playlistName});
  }

  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    final db = await _getDatabase();
    await db.insert('playlistSongs', {'playlistId': playlistId, 'songPath': songPath});
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    final db = await _getDatabase();
    await db.delete('playlistSongs', where: 'playlistId = ? AND songPath = ?', whereArgs: [playlistId, songPath]);
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await _getDatabase();
    await db.delete('playlistSongs', where: 'playlistId = ?', whereArgs: [playlistId]);
    await db.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
  }
}
