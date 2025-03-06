import 'package:sqflite/sqflite.dart';

final class DatabaseHelper {
  static const _databaseName = 'strayker_music.db';

  static Future<Database> getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_databaseName';

    return openDatabase(path, version: 1, onCreate: (db, version) {
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
        INSERT INTO settings VALUES (null, "playedSongsMaxAmount", 0)
      ''');
      db.execute('''
        INSERT INTO storageLocations VALUES (null, "/storage/emulated/0/Music")
      ''');
    });
  }

  Future<List<Map<String, dynamic>>> getAllData(String tableName) async {
    final db = await getDatabase();

    return db.query(tableName);
  }

  Future<List<Map<String, dynamic>>> getDataById(String tableName, int id) async {
    final db = await getDatabase();

    return db.query(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertData(String tableName, List<Map<String, dynamic>> data) async {
    final db = await getDatabase();

    for (var row in data) {
      await db.insert(tableName, row);
    }
  }

  Future<void> updateData(String tableName, int id, Map<String, dynamic> data) async {
    final db = await getDatabase();

    await db.update(tableName, data);
  }

  Future<void> updateDataByName(String tableName, String name, Map<String, dynamic> data) async {
    final db = await getDatabase();

    await db.update(tableName, where: "name = ?", whereArgs: [name], data);
  }

  Future<void> deleteData(String tableName, int id) async {
    final db = await getDatabase();

    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cleanTable(String tableName) async {
    final db = await getDatabase();

    await db.delete(tableName);
  }
}
