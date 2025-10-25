import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Widgets/playlist_view.dart';

Future<void> main() async {
  final SoundFilesReader filesReader = SoundFilesReader();
  final audioHandler = await AudioService.init(
    builder: () => DefaultAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'pl.straykersoftware.strayker_music.channel.audio',
      androidNotificationChannelName: Constants.appName,
    ),
  );
  final DatabaseHelper dbHelper = DatabaseHelper();
  List<MusicFile> files = await filesReader.getMusicFiles();

  runApp(
    MultiProvider(
      providers: [
        Provider<List<MusicFile>>.value(value: files),
        Provider<SoundPlayer>(create: (_) => SoundPlayer(handler: audioHandler)),
        Provider<DatabaseHelper>.value(value: dbHelper),
        ListenableProvider(create: (ctx) => PlaylistManager(databaseHelper: ctx.read<DatabaseHelper>(), allSongs: ctx.read<List<MusicFile>>())),
        Provider<SoundCollectionManager>(create: (ctx) => SoundCollectionManager(player: ctx.read<SoundPlayer>(), songs: ctx.read<List<MusicFile>>())),
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
          brightness: Brightness.dark
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const PlaylistView(title: Constants.appName),
    );
  }
}
