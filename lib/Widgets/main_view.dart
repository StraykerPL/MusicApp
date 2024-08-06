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
  final ScrollController _musicListScrollControl = ScrollController();
  PlayerStateEnum _currentState = PlayerStateEnum.musicNotLoaded;

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer(songs: _filesReader.getMusicFiles());
    _soundPlayer.availableSongs.sort((firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
  }

  Icon getDefaultIconWidget(IconData iconToSet) {
    return Icon(iconToSet, color: Theme.of(context).colorScheme.primary, size: 24.0);
  }

  Row createControlPanelWidget(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentState == PlayerStateEnum.musicNotLoaded ? null : () => {
            setState(() {
              _currentState = _soundPlayer.resumeOrPauseSong();
            })
          },
          child: _currentState == PlayerStateEnum.playing ?
            getDefaultIconWidget(Icons.pause) :
            getDefaultIconWidget(Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentState = _soundPlayer.playRandomMusic();
            });
          },
          child: getDefaultIconWidget(Icons.shuffle),
        ),
        ElevatedButton(
          onPressed: _currentState == PlayerStateEnum.musicNotLoaded ? null : () => {
            _musicListScrollControl.jumpTo(
              _musicListScrollControl.positions.last.maxScrollExtent
            )
          },
          child: getDefaultIconWidget(Icons.music_note),
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
        title: Text(
          _soundPlayer.availableSongs.first.name,
          maxLines: 1,
          overflow: TextOverflow.fade,
        ),
      ),
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_soundPlayer.availableSongs[index].name),
          trailing: _soundPlayer.availableSongs[index] == _soundPlayer.currentlySelectedSong ?
            getDefaultIconWidget(Icons.music_note) : null,
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
        controller: _musicListScrollControl,
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