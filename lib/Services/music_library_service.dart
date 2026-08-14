import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/music_scan_result.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';

final class MusicLibraryService {
  const MusicLibraryService({
    required MusicFileRepository musicFileRepository,
    required SettingsSnapshotRepository settingsSnapshotRepository,
  })  : _musicFileRepository = musicFileRepository,
        _settingsSnapshotRepository = settingsSnapshotRepository;

  final MusicFileRepository _musicFileRepository;
  final SettingsSnapshotRepository _settingsSnapshotRepository;

  Future<MusicScanResult> loadMusic() async {
    final SettingsSnapshot settings = await _settingsSnapshotRepository.get();
    final MusicScanResult result = await _musicFileRepository.getAll(
      settings.storageLocations,
    );
    final List<MusicFile> sortedSongs = List<MusicFile>.of(result.songs)
      ..sort(
        (MusicFile firstSong, MusicFile secondSong) =>
            firstSong.name.compareTo(secondSong.name),
      );

    return MusicScanResult(
      songs: List<MusicFile>.unmodifiable(sortedSongs),
      skippedLocations: result.skippedLocations,
    );
  }
}
