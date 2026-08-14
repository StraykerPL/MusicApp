import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:strayker_music/Models/music_file.dart';

void main() {
  test('normalized absolute path provides stable value and media identity', () {
    final first = MusicFile()..filePath = './music/../music/Song.MP3';
    final second = MusicFile()..filePath = path.absolute('music/Song.MP3');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.filePath, path.normalize(path.absolute('music/Song.MP3')));
    expect(first.mediaItemMetaData.id, first.filePath);
    expect(first.name, 'Song');
  });
}
