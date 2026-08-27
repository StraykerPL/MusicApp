import 'package:flutter_test/flutter_test.dart';
import 'package:strayker_music/Models/music_file.dart';

void main() {
  test('uses the opaque content URI for identity and MediaItem metadata', () {
    final uri = Uri.parse('content://media/external_primary/audio/media/42');
    final first = MusicFile(sourceUri: uri, displayName: 'Song.MP3');
    final second = MusicFile(sourceUri: uri, displayName: 'Renamed.mp3');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first.sourceUri, uri);
    expect(first.mediaItemMetaData.id, uri.toString());
    expect(first.name, 'Song');
  });

  test('rejects non-content music locators', () {
    expect(
      () => MusicFile(
        sourceUri: Uri.file('/storage/emulated/0/Music/song.mp3'),
        displayName: 'song.mp3',
      ),
      throwsArgumentError,
    );
  });
}
