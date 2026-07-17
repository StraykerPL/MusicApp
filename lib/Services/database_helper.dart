import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:strayker_music/Constants/database_constants.dart';

typedef DatabaseProvider = Future<Database> Function();

class DatabaseHelper {
  static const _databaseName = 'strayker_music.db';
  static const _databaseVersion = 2;

  DatabaseHelper({DatabaseProvider? databaseProvider})
      : _databaseProvider = databaseProvider ?? _openDatabase;

  final DatabaseProvider _databaseProvider;

  static Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_databaseName';

    return openDatabase(
      path,
      version: _databaseVersion,
      singleInstance: true,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedInitialValues(db);
        await _seedDebugPlaylists(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('PRAGMA foreign_keys = OFF');
          try {
            await _upgradeToVersion2(db);
          } finally {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        }
      },
    );
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.settingsTableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.storagePathsTableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.playlistsTableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.playlistSongsTableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlistId INTEGER NOT NULL,
        songPath TEXT NOT NULL,
        FOREIGN KEY (playlistId)
          REFERENCES ${DatabaseConstants.playlistsTableName} (id)
          ON DELETE CASCADE,
        UNIQUE (playlistId, songPath)
      )
    ''');
  }

  static Future<void> _seedInitialValues(DatabaseExecutor db) async {
    await db.insert(DatabaseConstants.settingsTableName, {
      'name': DatabaseConstants.playedSongsMaxAmountTableValueName,
      'value': DatabaseConstants.playedSongsMaxAmountDefault,
    });
    await db.insert(DatabaseConstants.storagePathsTableName, {
      'name': DatabaseConstants.soundStorageLocationsDefault.first,
    });
  }

  static Future<void> _seedDebugPlaylists(DatabaseExecutor db) async {
    if (!kDebugMode) {
      return;
    }
    final batch = db.batch();
    for (final name in ['Playlist 1', 'Playlist 2', 'Playlist 3']) {
      batch.insert(DatabaseConstants.playlistsTableName, {'name': name});
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgradeToVersion2(Database db) async {
    await db.transaction((transaction) async {
      await transaction.execute('ALTER TABLE settings RENAME TO settings_v1');
      await transaction.execute(
        'ALTER TABLE storageLocations RENAME TO storageLocations_v1',
      );
      await transaction.execute('ALTER TABLE playlists RENAME TO playlists_v1');
      await transaction.execute(
        'ALTER TABLE playlistSongs RENAME TO playlistSongs_v1',
      );
      await _createSchema(transaction);
      await transaction.execute('''
        INSERT INTO settings (name, value)
        SELECT name, value FROM settings_v1
        WHERE name IS NOT NULL AND value IS NOT NULL
        GROUP BY name
      ''');
      await transaction.execute('''
        INSERT INTO storageLocations (name)
        SELECT DISTINCT name FROM storageLocations_v1 WHERE name IS NOT NULL
      ''');
      await transaction.execute('''
        INSERT INTO playlists (id, name)
        SELECT MIN(id), name FROM playlists_v1
        WHERE name IS NOT NULL GROUP BY name
      ''');
      await transaction.execute('''
        INSERT INTO playlistSongs (playlistId, songPath)
        SELECT DISTINCT songs.playlistId, songs.songPath
        FROM playlistSongs_v1 songs
        INNER JOIN playlists ON playlists.id = songs.playlistId
        WHERE songs.playlistId IS NOT NULL AND songs.songPath IS NOT NULL
      ''');
      for (final table in [
        'settings_v1',
        'storageLocations_v1',
        'playlists_v1',
        'playlistSongs_v1',
      ]) {
        await transaction.execute('DROP TABLE $table');
      }
    });
  }

  Future<List<Map<String, Object?>>> queryPlaylists() async {
    final db = await _databaseProvider();
    return db.query(DatabaseConstants.playlistsTableName);
  }

  Future<Map<String, Object?>?> queryPlaylistByName(String name) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      DatabaseConstants.playlistsTableName,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertPlaylist(String name) async {
    final db = await _databaseProvider();
    return db.insert(DatabaseConstants.playlistsTableName, {'name': name});
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await _databaseProvider();
    await db.transaction((transaction) async {
      await transaction.delete(
        DatabaseConstants.playlistSongsTableName,
        where: 'playlistId = ?',
        whereArgs: [playlistId],
      );
      await transaction.delete(
        DatabaseConstants.playlistsTableName,
        where: 'id = ?',
        whereArgs: [playlistId],
      );
    });
  }

  Future<List<String>> queryPlaylistSongPaths(int playlistId) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      DatabaseConstants.playlistSongsTableName,
      columns: ['songPath'],
      where: 'playlistId = ?',
      whereArgs: [playlistId],
    );
    return [for (final row in rows) row['songPath'] as String];
  }

  Future<void> insertPlaylistSong(int playlistId, String songPath) async {
    final db = await _databaseProvider();
    await db.insert(DatabaseConstants.playlistSongsTableName, {
      'playlistId': playlistId,
      'songPath': songPath,
    });
  }

  Future<void> deletePlaylistSong(int playlistId, String songPath) async {
    final db = await _databaseProvider();
    await db.delete(
      DatabaseConstants.playlistSongsTableName,
      where: 'playlistId = ? AND songPath = ?',
      whereArgs: [playlistId, songPath],
    );
  }

  Future<bool> queryPlaylistContainsSong(
    int playlistId,
    String songPath,
  ) async {
    final db = await _databaseProvider();
    final rows = await db.query(
      DatabaseConstants.playlistSongsTableName,
      columns: ['id'],
      where: 'playlistId = ? AND songPath = ?',
      whereArgs: [playlistId, songPath],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, Object?>>> queryPlaylistsContainingSong(
    String songPath,
  ) async {
    final db = await _databaseProvider();
    return db.rawQuery('''
      SELECT playlists.id, playlists.name
      FROM ${DatabaseConstants.playlistsTableName} playlists
      INNER JOIN ${DatabaseConstants.playlistSongsTableName} songs
        ON songs.playlistId = playlists.id
      WHERE songs.songPath = ?
    ''', [songPath]);
  }

  Future<Map<String, Object?>?> queryPlayedSongsMaxAmount() async {
    final db = await _databaseProvider();
    final rows = await db.query(
      DatabaseConstants.settingsTableName,
      columns: ['value'],
      where: 'name = ?',
      whereArgs: [DatabaseConstants.playedSongsMaxAmountTableValueName],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<String>> queryStorageLocations() async {
    final db = await _databaseProvider();
    final rows = await db.query(
      DatabaseConstants.storagePathsTableName,
      columns: ['name'],
    );
    return [for (final row in rows) row['name'] as String];
  }

  Future<void> updatePlayedSongsMaxAmount(int value) async {
    final db = await _databaseProvider();
    await db.update(
      DatabaseConstants.settingsTableName,
      {'value': value},
      where: 'name = ?',
      whereArgs: [DatabaseConstants.playedSongsMaxAmountTableValueName],
    );
  }

  Future<void> replaceSettingsData({
    required int playedSongsMaxAmount,
    required List<String> storageLocations,
  }) async {
    final db = await _databaseProvider();
    await db.transaction((transaction) async {
      await transaction.update(
        DatabaseConstants.settingsTableName,
        {'value': playedSongsMaxAmount},
        where: 'name = ?',
        whereArgs: [DatabaseConstants.playedSongsMaxAmountTableValueName],
      );
      await transaction.delete(DatabaseConstants.storagePathsTableName);
      final batch = transaction.batch();
      for (final path in storageLocations) {
        batch.insert(DatabaseConstants.storagePathsTableName, {'name': path});
      }
      await batch.commit(noResult: true);
    });
  }
}
