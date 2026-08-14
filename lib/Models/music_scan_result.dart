import 'package:strayker_music/Models/music_file.dart';

final class MusicScanResult {
  MusicScanResult({
    required List<MusicFile> songs,
    required List<String> skippedLocations,
  })  : songs = List<MusicFile>.unmodifiable(songs),
        skippedLocations = List<String>.unmodifiable(skippedLocations);

  final List<MusicFile> songs;
  final List<String> skippedLocations;
}
