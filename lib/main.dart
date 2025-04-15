import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/main_drawer.dart';
import 'package:strayker_music/Widgets/playlist_view.dart';
import 'package:strayker_music/Widgets/settings.dart';

Future<void> main() async {
  final SoundFilesReader filesReader = SoundFilesReader();

  final audioHandler = await AudioService.init(
    builder: () => DefaultAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'pl.straykersoftware.strayker_music.channel.audio',
      androidNotificationChannelName: Constants.appName,
    ),
  );
  List<MusicFile> files = await filesReader.getMusicFiles();

  // TODO: Add Redux container.
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper()),
        Provider(create: (_) => const SettingsView()),
        Provider<MainDrawer>(create: (_) => const MainDrawer()),
        ProxyProvider0<SoundPlayer>(update: (_, __) => SoundPlayer(handler: audioHandler)),
        ProxyProvider0<SoundCollectionManager>(update: (context, __) => SoundCollectionManager(player: context.watch<SoundPlayer>(), songs: files)),
        ProxyProvider0<PlaylistView>(
          update: (context, __) => PlaylistView(title: Constants.appName, audioHandler: audioHandler, soundCollectionManager: context.watch<SoundCollectionManager>())
        )
      ],
      child: const MyApp(),
    )
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
          brightness: Brightness.dark
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: context.watch<PlaylistView>(),
    );
  }
}
