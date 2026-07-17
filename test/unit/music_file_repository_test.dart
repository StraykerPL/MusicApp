import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';

void main() {
  test('recursively discovers only supported music files', () async {
    final directory = await Directory.systemTemp.createTemp('music_files_');
    addTearDown(() => directory.delete(recursive: true));
    final nested = Directory('${directory.path}/nested')..createSync();
    File('${directory.path}/alpha.mp3').writeAsStringSync('');
    File('${nested.path}/beta.mp3').writeAsStringSync('');
    File('${nested.path}/notes.txt').writeAsStringSync('');
    var permissionRequests = 0;
    final repository = MusicFileRepository(
      requestStoragePermission: () async => permissionRequests++,
    );

    final files = await repository.getAll([directory.path]);

    expect(permissionRequests, 1);
    expect(
      files.map((file) => file.name).toSet(),
      {'alpha', 'beta'},
    );
  });

  test('ignores inaccessible locations according to scanner behavior',
      () async {
    final repository = MusicFileRepository(
      requestStoragePermission: () async {},
    );

    expect(
      await repository.getAll(['/path/that/does/not/exist']),
      isEmpty,
    );
  });
}
