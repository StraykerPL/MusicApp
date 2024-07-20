import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'MusicApp'),
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
  List<FileSystemEntity> _files1 = [];
  List<FileSystemEntity> _files2 = [];
  List<FileSystemEntity> _songs = [];
  String selectedSongPath = "";

  void getMusicFiles() {
    Permission.manageExternalStorage.request();
    Directory dir1 = Directory('/storage/emulated/0/MicroSD/Muzyka');
    Directory dir2 = Directory('/storage/emulated/0/MicroSD/Muzyka One Republic');
    
    try {
      _files1 = dir1.listSync(recursive: true, followLinks: false);
      _files2 = dir2.listSync(recursive: true, followLinks: false);
    } catch (e) {
      print(e);
    }

    for(FileSystemEntity entity in _files1) {
      String path = entity.path;
      if(path.endsWith('.mp3')) {
        setState(() {
          _songs.add(entity);
        });
      }
    }

    for(FileSystemEntity entity in _files2) {
      String path = entity.path;
      if(path.endsWith('.mp3')) {
        setState(() {
          _songs.add(entity);
        });
      }
    }
  }

  void playSond(String songName) {
    player.stop();
    player.setUrl(songName);
    player.play();
  }

  void pauseSong() {
    if (player.playing) {
      player.pause();
    }
    else {
      player.play();
    }
  }

  void playRandomMusic() {
    int rand = Random().nextInt(_songs.length);
    selectedSongPath = _songs[rand].path;
    playSond(selectedSongPath);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => getMusicFiles());
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
              )],
            ),
            _songs.isNotEmpty ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _songs.length,
              prototypeItem: ListTile(
                title: Text(_songs.first.path),
              ),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_songs[index].path),
                  onTap: () => {
                    selectedSongPath = _songs[index].path
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
