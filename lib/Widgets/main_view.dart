import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_manager.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
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

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer();
    _soundManager = SoundFilesManager(player: _soundPlayer, songs: _filesReader.getMusicFiles());
    _searchMusicInputController.addListener(onSearchInputChanged);
  }

  // I don't know why, but here if I clone list of MusicFiles to perform dynamic search, UI thread's performance is starting to fluctuate.
  // Why reading data from storage (IO operation) repetedly is quicker than clone in-memory list of data?
  void onSearchInputChanged() {
    List<MusicFile> filteredFiles = _filesReader.getMusicFiles();
    filteredFiles.retainWhere((musicFile) => musicFile.name.toUpperCase().contains(_searchMusicInputController.value.text.toUpperCase()));
    setState(() {
      _soundManager.availableSongs = filteredFiles;
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
          setState(() {
            _isSearchBoxVisible = false;
          });
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
            int indexCalc = _soundManager.availableSongs.indexOf(_soundPlayer.currentSong!);
            
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
      itemCount: _soundManager.availableSongs.length,
      prototypeItem: ListTile(
        title: Text(
          _soundManager.availableSongs.first.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        )
      ),
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(
            _soundManager.availableSongs[index].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: _soundManager.availableSongs[index] == _soundPlayer.currentSong ?
            getDefaultIconWidget(context, Icons.music_note) : null,
          onTap: () => {
            setState(() {
              _currentState = _soundManager.selectAndPlaySong(index);
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
              _soundManager.availableSongs.isNotEmpty ?
                createMusicListWidget(context) :
                const Text("Welcome to Strayker Music!", softWrap: true,),
            )
          )
        ],
      )
    );
  }
}