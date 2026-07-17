import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';

typedef StoragePermissionRequester = Future<void> Function();

class MusicFileRepository {
  MusicFileRepository({StoragePermissionRequester? requestStoragePermission})
      : _requestStoragePermission =
            requestStoragePermission ?? _requestManageExternalStorage;

  final StoragePermissionRequester _requestStoragePermission;

  static Future<void> _requestManageExternalStorage() async {
    await Permission.manageExternalStorage.request();
  }

  Future<List<MusicFile>> getAll(List<String> storageLocations) async {
    await _requestStoragePermission();

    final songs = <MusicFile>[];
    for (final fileSystemPath in storageLocations) {
      final directory = Directory(fileSystemPath);
      List<FileSystemEntity> files = [];
      try {
        files = directory.listSync(recursive: true, followLinks: false);
      } catch (error) {
        debugPrint(error.toString());
      }

      for (final entity in files) {
        if (entity.path.endsWith(Constants.stringMp3Extension)) {
          final file = MusicFile()..filePath = entity.path;
          songs.add(file);
        }
      }
    }
    return songs;
  }
}
