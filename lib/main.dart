import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Services/database_helper.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Repositories/music_file_repository.dart';
import 'package:strayker_music/Repositories/playlist_repository.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';
import 'package:strayker_music/Widgets/playlist_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final databaseHelper = DatabaseHelper();
  final playlistRepository = PlaylistRepository(
    databaseHelper: databaseHelper,
  );
  final settingsSnapshotRepository = SettingsSnapshotRepository(
    databaseHelper: databaseHelper,
  );
  final musicFileRepository = MusicFileRepository();
  final settings = await settingsSnapshotRepository.get();
  final files = await musicFileRepository.getAll(settings.storageLocations);
  final audioHandler = await AudioService.init(
    builder: () => DefaultAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'pl.straykersoftware.strayker_music.channel.audio',
      androidNotificationChannelName: Constants.appName,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<List<MusicFile>>.value(value: files),
        Provider<SoundPlayer>(
            create: (_) => SoundPlayer(handler: audioHandler)),
        Provider<PlaylistRepository>.value(value: playlistRepository),
        Provider<SettingsSnapshotRepository>.value(
          value: settingsSnapshotRepository,
        ),
        ChangeNotifierProvider(
            create: (ctx) => PlaylistManager(
                playlistRepository: ctx.read<PlaylistRepository>(),
                allSongs: ctx.read<List<MusicFile>>())),
        Provider<SoundCollectionManager>(
          create: (ctx) => SoundCollectionManager(
            player: ctx.read<SoundPlayer>(),
            settingsSnapshotRepository: ctx.read<SettingsSnapshotRepository>(),
          ),
        ),
        ChangeNotifierProvider<PlaylistViewModel>(
          create: (ctx) => PlaylistViewModel(
            playlistManager: ctx.read<PlaylistManager>(),
            soundCollectionManager: ctx.read<SoundCollectionManager>(),
          )..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Constants.appName,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A2D47),
            primary: const Color(0xFF1A2D47),
            brightness: Brightness.dark),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const PlaylistView(),
    );
  }
}
