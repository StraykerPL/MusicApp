import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, required this.title});
  final String title;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final SoundPlayer _soundPlayer = SoundPlayer();
  final SoundFilesReader _filesReader = SoundFilesReader();

  @override
  void initState() {
    super.initState();
    _soundPlayer.availableSongs = _filesReader.getMusicFiles();
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