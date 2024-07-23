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

  Row createControlPanelWidget(BuildContext context) {
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
            child: _currentState == PlayerStateEnum.playing ?
              Icon(Icons.pause, color: Theme.of(context).colorScheme.primary, size: 24.0) :
              Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary, size: 24.0)
          ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentState = _soundPlayer.playRandomMusic();
            });
          },
          child: Icon(Icons.shuffle, color: Theme.of(context).colorScheme.primary, size: 24.0),
        )
      ],
    );
  }

  ListView createMusicListWidget(BuildContext context) {
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
          trailing: _soundPlayer.availableSongs[index] == _soundPlayer.currentlySelectedSong ?
            Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary, size: 24.0) : null,
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
            createControlPanelWidget(context),
            _soundPlayer.availableSongs.isNotEmpty ?
              createMusicListWidget(context) :
              const Text("No files found, if you just assigned permission to the app, restart to load files.", softWrap: true,)
          ],
        ),
      ),
    );
  }
}