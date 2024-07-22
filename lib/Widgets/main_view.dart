import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, required this.title});
  final String title;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final player = AudioPlayer();
  final List<MusicFile> _songs = [];
  final List<String> directories = [
    '/storage/emulated/0/MicroSD/Muzyka',
    '/storage/emulated/0/MicroSD/Muzyka One Republic'
  ];
  List<FileSystemEntity> _files = [];
  String selectedSongPath = Constants.stringEmpty;

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
        if(entity.path.endsWith(Constants.stringMp3Extension)) {
          final MusicFile newFile = MusicFile();
          newFile.filePath = entity.path;
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