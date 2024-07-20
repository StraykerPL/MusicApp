import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Models/music_file.dart';

void main() {
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
          seedColor: Colors.blue,
          brightness: Brightness.dark
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const MyHomePage(title: 'Strayker Music'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final player = AudioPlayer();
  final List<MusicFile> _songs = [];
  final List<String> directories = [
    '/storage/emulated/0/MicroSD/Muzyka',
    '/storage/emulated/0/MicroSD/Muzyka One Republic'
  ];
  List<FileSystemEntity> _files = [];
  String selectedSongPath = "";

  String getFileName(String fullPath) {
    String name = "";

    for(String directory in directories) {
      if(fullPath.startsWith(directory)) {
        name = fullPath.replaceAll("$directory/", "");
        name = name.replaceAll(".mp3", "");
      }
    }

    return name;
  }

  void getMusicFiles() {
    Permission.manageExternalStorage.request();

    for(String fileSystemPath in directories) {
      final Directory dir = Directory(fileSystemPath);

      try {
      _files = dir.listSync(recursive: true, followLinks: false);
      } catch (e) {
        debugPrint(e.toString());
      }

      for(FileSystemEntity entity in _files) {
          if(entity.path.endsWith('.mp3')) {
          final MusicFile newFile = MusicFile();
          newFile.filePath = entity.path;
          newFile.name = getFileName(newFile.filePath);
          setState(() {
            _songs.add(newFile);
          });
        }
      }
    }
  }

  void playSond(String songName) {
    player.stop();
    player.setUrl(songName);
    player.play();
  }

  void pauseSong() {
    if(player.playing) {
      player.pause();
    }
    else {
      player.play();
    }
  }

  void playRandomMusic() {
    playSond(_songs[Random().nextInt(_songs.length)].filePath);
  }

  @override
  void initState() {
    super.initState();
    getMusicFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    playSond(selectedSongPath);
                  },
                  child: const Text('Play'),
                ),
                ElevatedButton(
                  onPressed: () {
                    pauseSong();
                  },
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: () {
                    playRandomMusic();
                  },
                  child: const Text('Random'),
                )
              ],
            ),
            _songs.isNotEmpty ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _songs.length,
              prototypeItem: ListTile(
                title: Text(_songs.first.name),
              ),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_songs[index].name),
                  onTap: () => {
                    selectedSongPath = _songs[index].filePath
                  },
                );
              },
            ) : const Text("Empty Music List")
          ],
        ),
      ),
    );
  }
}
