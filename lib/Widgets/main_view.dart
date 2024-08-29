import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/player_state_enum.dart';
import 'package:strayker_music/Models/music_file.dart';

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
  bool _isSearchBoxVisible = false;
  final _searchMusicInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer(songs: _filesReader.getMusicFiles());
    _soundPlayer.availableSongs.sort((firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
    _searchMusicInputController.addListener(onSearchInputChanged);
  }

  void onSearchInputChanged() {
    List<MusicFile> filteredFiles = _filesReader.getMusicFiles();
    filteredFiles.retainWhere((musicFile) => musicFile.name.toUpperCase().contains(_searchMusicInputController.value.text.toUpperCase()));
    setState(() {
      _soundPlayer.availableSongs = filteredFiles;
    });
  }

  @override
  void dispose() {
    _searchMusicInputController.dispose();
    super.dispose();
  }

  Icon getDefaultIconWidget(IconData iconToSet) {
    return Icon(iconToSet, color: Theme.of(context).colorScheme.inversePrimary, size: 24.0);
  }

  Row createControlPanelWidget(BuildContext context) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentState == PlayerStateEnum.musicNotLoaded ? null : () {
            int indexCalc = _soundPlayer.availableSongs.indexOf(_soundPlayer.currentlySelectedSong!);
            
            if(index != indexCalc) {
              index = indexCalc;
              _musicListScrollControl.jumpTo(
                index * 50
              );
            }
            else {
              index = 0;
              _musicListScrollControl.jumpTo(index.toDouble());
            }
          },
          child: getDefaultIconWidget(Icons.music_note),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _searchMusicInputController.clear();
              _isSearchBoxVisible = !_isSearchBoxVisible;
            });
          },
          child: getDefaultIconWidget(Icons.search),
        ),
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
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        )
      ),
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(
            _soundPlayer.availableSongs[index].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: createControlPanelWidget(context),
          ),
          _isSearchBoxVisible ? Expanded(
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: _searchMusicInputController,
                autofocus: true,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _isSearchBoxVisible = false;
                  });
                },
              ),
            )
          ) as Widget : const SizedBox.shrink(),
          Expanded(
            flex: 10,
            child: SingleChildScrollView(
              controller: _musicListScrollControl,
              child: 
              _soundPlayer.availableSongs.isNotEmpty ?
                createMusicListWidget(context) :
                const Text("Welcome to Strayker Music!", softWrap: true,),
            )
          )
        ],
      )
    );
  }
}