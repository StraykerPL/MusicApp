import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeDatabase {
  final Database database;

  FakeDatabase._(this.database);

  static Future<FakeDatabase> seeded() async {
    sqfliteFfiInit();

    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              value TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE storageLocations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE playlists (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE playlistSongs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              playlistId INTEGER,
              songPath TEXT,
              FOREIGN KEY (playlistId) REFERENCES playlists (id)
            )
          ''');

          await db.insert('settings', {
            'name': 'playedSongsMaxAmount',
            'value': '0',
          });
          await db.insert('storageLocations', {
            'name': '/storage/emulated/0/Music',
          });
        },
      ),
    );

    return FakeDatabase._(database);
  }

  Future<List<Map<String, dynamic>>> snapshot(String table) {
    return database.query(table);
  }

  Future<void> close() {
    return database.close();
  }
}
