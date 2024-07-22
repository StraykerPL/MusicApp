import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, required this.title});
  final String title;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final SoundPlayer _soundPlayer = SoundPlayer();
  final List<String> directories = [
    '/storage/emulated/0/MicroSD/Muzyka',
    '/storage/emulated/0/MicroSD/Muzyka One Republic'
  ];
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _soundPlayer.availableSongs = getMusicFiles();
  }

  List<MusicFile> getMusicFiles() {
    Permission.manageExternalStorage.request();

    List<MusicFile> songs = [];
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
            songs.add(newFile);
          });
        }
      }
    }

    return songs;
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
                    _soundPlayer.playSong();
                  },
                  child: const Text('Play'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _soundPlayer.pauseSong();
                  },
                  child: const Text('Pause'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _soundPlayer.playRandomMusic();
                  },
                  child: const Text('Random'),
                )
              ],
            ),
            _soundPlayer.availableSongs.isNotEmpty ? ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _soundPlayer.availableSongs.length,
              prototypeItem: ListTile(
                title: Text(_soundPlayer.availableSongs.first.name),
              ),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_soundPlayer.availableSongs[index].name),
                  onTap: () => {
                    _soundPlayer.setCurrentSong(index)
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