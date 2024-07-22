import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, required this.title});
  final String title;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final SoundFilesReader _filesReader = SoundFilesReader();
  late final SoundPlayer _soundPlayer;
  PlayerStateEnum _currentState = PlayerStateEnum.musicNotLoaded;

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer(songs: _filesReader.getMusicFiles());
  }

  Row createControlPanelWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if(_currentState != PlayerStateEnum.musicNotLoaded)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentState = _soundPlayer.resumeOrPauseSong();
              });
            },
            child: Text(_currentState == PlayerStateEnum.playing ? 'Pause' : 'Play'),
          ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentState = _soundPlayer.playRandomMusic();
            });
          },
          child: const Text('Random'),
        )
      ],
    );
  }

  ListView createMusicListWidget() {
    return ListView.builder(
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
            setState(() {
              _currentState = _soundPlayer.selectAndPlaySong(index);
            })
          },
        );
      },
    );
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
            createControlPanelWidget(),
            _soundPlayer.availableSongs.isNotEmpty ? createMusicListWidget() : const Text("Empty Music List")
          ],
        ),
      ),
    );
  }
}