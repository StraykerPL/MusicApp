import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Models/storage_permission_denied_exception.dart';

typedef StoragePermissionRequester = Future<PermissionStatus> Function();

class MusicFileRepository {
  MusicFileRepository({StoragePermissionRequester? requestStoragePermission})
      : _requestStoragePermission =
            requestStoragePermission ?? _requestPermissions;

  final StoragePermissionRequester _requestStoragePermission;

  static Future<PermissionStatus> _requestPermissions() {
    return Permission.manageExternalStorage.request();
  }

  Future<MusicScanResult> getAll(List<String> storageLocations) async {
    final PermissionStatus permissionStatus = await _requestStoragePermission();
    if (!permissionStatus.isGranted) {
      throw StoragePermissionDeniedException(permissionStatus);
    }

    final Map<String, MusicFile> songsByPath = <String, MusicFile>{};
    final List<String> skippedLocations = <String>[];
    final Set<String> normalizedLocations = storageLocations
        .map((String location) => path.normalize(path.absolute(location)))
        .toSet();

    for (final String location in normalizedLocations) {
      final Directory directory = Directory(location);
      try {
        if (!await directory.exists()) {
          skippedLocations.add(location);
          
          continue;
        }
        await for (final FileSystemEntity entity
            in directory.list(recursive: true, followLinks: false)) {
          if (entity is File &&
              path.extension(entity.path).toLowerCase() ==
                  Constants.stringMp3Extension) {
            final String normalizedPath =
                path.normalize(path.absolute(entity.path));
            songsByPath.putIfAbsent(
              normalizedPath,
              () => MusicFile()..filePath = normalizedPath,
            );
          }
        }
      } on FileSystemException {
        skippedLocations.add(location);
      }
    }

    return MusicScanResult(
      songs: songsByPath.values.toList(growable: false),
      skippedLocations: skippedLocations,
    );
  }
}
