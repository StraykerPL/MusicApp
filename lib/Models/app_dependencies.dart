import 'package:strayker_music/Repositories/playlist_repository.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/music_library_service.dart';

final class AppDependencies {
  const AppDependencies({
    required this.playlistRepository,
    required this.settingsSnapshotRepository,
    required this.musicLibraryService,
    required this.audioHandler,
  });

  final PlaylistRepository playlistRepository;
  final SettingsSnapshotRepository settingsSnapshotRepository;
  final MusicLibraryService musicLibraryService;
  final DefaultAudioHandler audioHandler;

  Future<void> dispose() => audioHandler.dispose();
}
