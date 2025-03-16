import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'Widgets/main_view.dart';

Future<void> main() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
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
      home: const MainView(title: 'Strayker Music'),
    );
  }
}
