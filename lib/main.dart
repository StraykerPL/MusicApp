import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'Widgets/main_view.dart';

late final BaseAudioHandler _audioHandler;

Future<void> main() async {
  // TODO: Add DI container.
  _audioHandler = await AudioService.init(
    builder: () => SoundPlayer(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'pl.straykersoftware.strayker_music.channel.audio',
      androidNotificationChannelName: 'Strayker Music',
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Strayker Music',
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
      home: MainView(title: 'Strayker Music', audioHandler: _audioHandler),
    );
  }
}
