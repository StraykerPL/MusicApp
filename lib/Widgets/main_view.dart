import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_manager.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/get_default_icon_widget.dart';

class MainView extends StatefulWidget {
  const MainView({super.key, required this.title});
  final String title;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final SoundFilesReader _filesReader = SoundFilesReader();
  final ScrollController _musicListScrollControl = ScrollController();
  final TextEditingController _searchMusicInputController = TextEditingController();
  late final SoundPlayer _soundPlayer;
  late final SoundFilesManager _soundManager;
  PlayerStateEnum _currentState = PlayerStateEnum.musicNotLoaded;
  bool _isSearchBoxVisible = false;
  List<MusicFile> displayedFiles = [];

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer();
    _soundManager = SoundFilesManager(player: _soundPlayer, songs: _filesReader.getMusicFiles());
    displayedFiles = _soundManager.availableSongs;
    _searchMusicInputController.addListener(onSearchInputChanged);
  }

  void onSearchInputChanged() {
    if (_searchMusicInputController.value.text == Constants.stringEmpty) {
      setState(() {
        displayedFiles = _soundManager.availableSongs;
      });
    }

    List<MusicFile> filteredFiles = [];
    for (var soundFile in _soundManager.availableSongs) {
      if (soundFile.name.toUpperCase().contains(_searchMusicInputController.value.text.toUpperCase()))
      {
        filteredFiles.add(soundFile);
      }
    }

    setState(() {
      displayedFiles = filteredFiles;
    });
  }

  @override
  void dispose() {
    _searchMusicInputController.dispose();
    super.dispose();
  }

  SizedBox createSearchInputbox() {
    return SizedBox(
      width: double.infinity,
      child: TextField(
        controller: _searchMusicInputController,
        autofocus: true,
        onTapOutside: (event) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
      ),
    );
  }

  Row createControlPanelWidget(BuildContext context) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentState == PlayerStateEnum.musicNotLoaded ? null : () {
            var indexCalc = _soundManager.availableSongs.indexOf(_soundPlayer.currentSong as MusicFile);

            if(index != indexCalc) {
              index = indexCalc;
              _musicListScrollControl.jumpTo(
                index * 60
              );
            }
            else {
              index = 0;
              _musicListScrollControl.jumpTo(index.toDouble());
            }
          },
          child: getDefaultIconWidget(context, Icons.music_note),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _searchMusicInputController.clear();
              _isSearchBoxVisible = !_isSearchBoxVisible;
            });
          },
          child: getDefaultIconWidget(context, Icons.search),
        ),
        ElevatedButton(
          onPressed: _currentState == PlayerStateEnum.musicNotLoaded ? null : () => {
            setState(() {
              _currentState = _soundPlayer.resumeOrPauseSong();
            })
          },
          child: _currentState == PlayerStateEnum.playing ?
            getDefaultIconWidget(context, Icons.pause) :
            getDefaultIconWidget(context, Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentState = _soundManager.playRandomMusic();
            });
          },
          child: getDefaultIconWidget(context, Icons.shuffle),
        ),
      ],
    );
  }

  ListView createMusicListWidget(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: displayedFiles.length,
      itemBuilder: (context, index) {
        return ListTile(
          minTileHeight: 60,
          title: Text(
            displayedFiles[index].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: displayedFiles[index].name == _soundPlayer.currentSong?.name ?
            getDefaultIconWidget(context, Icons.music_note) : null,
          onTap: () => {
            setState(() {
              _currentState = _soundManager.selectAndPlaySong(displayedFiles[index].name);
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: createControlPanelWidget(context),
          ),
          _isSearchBoxVisible ? Expanded(
            child: createSearchInputbox()
          ) as Widget : const SizedBox.shrink(),
          Expanded(
            flex: 10,
            child: SingleChildScrollView(
              controller: _musicListScrollControl,
              child: 
              displayedFiles.isNotEmpty ?
                createMusicListWidget(context) :
                const Text("Welcome to Strayker Music!", softWrap: true),
            )
          )
        ],
      )
    );
  }
}