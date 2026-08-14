import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Models/storage_permission_denied_exception.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';

void main() {
  test('recursively discovers only supported music files', () async {
    final directory = await Directory.systemTemp.createTemp('music_files_');
    addTearDown(() => directory.delete(recursive: true));
    final nested = Directory('${directory.path}/nested')..createSync();
    File('${directory.path}/alpha.mp3').writeAsStringSync('');
    File('${nested.path}/beta.mp3').writeAsStringSync('');
    File('${nested.path}/upper.MP3').writeAsStringSync('');
    File('${nested.path}/notes.txt').writeAsStringSync('');
    var permissionRequests = 0;
    final repository = MusicFileRepository(
      requestStoragePermission: () async {
        permissionRequests++;
        return PermissionStatus.granted;
      },
    );

    final result = await repository.getAll([
      directory.path,
      '${directory.path}/.',
    ]);

    expect(permissionRequests, 1);
    expect(
      result.songs.map((file) => file.name).toSet(),
      {'alpha', 'beta', 'upper'},
    );
    expect(result.songs, hasLength(3));
  });

  test('keeps accessible songs while reporting skipped locations', () async {
    final directory = await Directory.systemTemp.createTemp('music_files_');
    addTearDown(() => directory.delete(recursive: true));
    File('${directory.path}/available.mp3').writeAsStringSync('');
    final repository = MusicFileRepository(
      requestStoragePermission: () async => PermissionStatus.granted,
    );

    final result = await repository.getAll([
      '/path/that/does/not/exist',
      directory.path,
    ]);

    expect(result.songs.single.name, 'available');
    expect(result.skippedLocations, hasLength(1));
  });

  test('ignores inaccessible locations according to scanner behavior',
      () async {
    final repository = MusicFileRepository(
      requestStoragePermission: () async => PermissionStatus.granted,
    );

    final result = await repository.getAll(['/path/that/does/not/exist']);

    expect(result.songs, isEmpty);
    expect(result.skippedLocations, hasLength(1));
  });

  test('throws a typed failure when storage permission is denied', () async {
    final repository = MusicFileRepository(
      requestStoragePermission: () async => PermissionStatus.denied,
    );

    expect(
      repository.getAll(const <String>[]),
      throwsA(isA<StoragePermissionDeniedException>()),
    );
  });
}
