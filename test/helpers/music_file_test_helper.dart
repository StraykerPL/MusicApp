import 'package:strayker_music/Models/music_file.dart';

MusicFile createSong(String path) {
  final sourceUri = path.startsWith('content://')
      ? Uri.parse(path)
      : Uri(
          scheme: 'content',
          host: 'test',
          pathSegments: [
            'audio',
            ...path.split('/').where((segment) => segment.isNotEmpty),
          ],
        );
  final displayName = path.split('/').last;
  return MusicFile(sourceUri: sourceUri, displayName: displayName);
}
