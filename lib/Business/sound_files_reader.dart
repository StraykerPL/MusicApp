import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundFilesReader {
  // final List<String> directories = [
  //   '/storage/emulated/0/MicroSD/Muzyka',
  //   '/storage/emulated/0/MicroSD/Muzyka One Republic'
  // ];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<MusicFile>> getMusicFiles() async {
    Permission.manageExternalStorage.request();

    List<MusicFile> songs = [];
    var directories = await _dbHelper.getAllData(DatabaseConstants.storagePathsTableName);
    for(final {"name": fileSystemPath as String} in directories) {
      final Directory dir = Directory(fileSystemPath);
      List<FileSystemEntity> files = [];

      try {
        files = dir.listSync(recursive: true, followLinks: false);
      } catch (e) {
        debugPrint(e.toString());
      }

      for(FileSystemEntity entity in files) {
        if(entity.path.endsWith(Constants.stringMp3Extension)) {
          final MusicFile newFile = MusicFile();
          newFile.filePath = entity.path;
          songs.add(newFile);
        }
      }
    }

    return songs;
  }
}