import 'package:strayker_music/Models/music_file.dart';

MusicFile createSong(String path) {
  final song = MusicFile();
  song.filePath = path;
  
  return song;
}
