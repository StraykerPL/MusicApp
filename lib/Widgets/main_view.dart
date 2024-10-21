import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:strayker_music/Business/sound_files_manager.dart';
import 'package:strayker_music/Business/sound_files_reader.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/get_default_icon_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strayker_music/Widgets/settings.dart';

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
  late final StreamSubscription<bool> _playerStatusSubscription;
  bool _isCurrentlyPlaying = false;
  bool _isSearchBoxVisible = false;
  List<MusicFile> displayedFiles = [];
  late final PackageInfo _packageInfo;

  @override
  void initState() {
    super.initState();
    _soundPlayer = SoundPlayer();
    _soundManager = SoundFilesManager(player: _soundPlayer, songs: _filesReader.getMusicFiles());
    displayedFiles = _soundManager.availableSongs;
    _searchMusicInputController.addListener(onSearchInputChanged);
    _playerStatusSubscription = _soundPlayer.isSoundPlaying();
    _playerStatusSubscription.onData((value) async {
      setState(() {
        _isCurrentlyPlaying = value;
      });
    });
    PackageInfo.fromPlatform().then((value) => _packageInfo = value);
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
    _playerStatusSubscription.cancel();
    super.dispose();
  }

  Row createControlPanelWidget(BuildContext context) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: !_isCurrentlyPlaying && _soundPlayer.currentSong == null ? null : () {
            var indexCalc = _soundManager.availableSongs.indexOf(_soundPlayer.currentSong as MusicFile);

            if(index != indexCalc) {
              index = indexCalc;
              var padding = MediaQuery.of(context).viewPadding;
              _musicListScrollControl.jumpTo(
                (index * 60) - ((MediaQuery.sizeOf(context).height - padding.top - padding.bottom - kToolbarHeight) / 2.5)
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
          onPressed: !_isCurrentlyPlaying && _soundPlayer.currentSong == null ? null : () => {
            _soundPlayer.resumeOrPauseSong()
          },
          child: _isCurrentlyPlaying && _soundPlayer.currentSong != null ?
            getDefaultIconWidget(context, Icons.pause) :
            getDefaultIconWidget(context, Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () {
            _soundManager.playRandomMusic();
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
            _soundManager.selectAndPlaySong(displayedFiles[index].name)
          },
        );
      },
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Strayker Music'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Version: ${_packageInfo.version}+${_packageInfo.buildNumber}\n\nOS Version: ${Platform.operatingSystemVersion}\n\nDart: ${Platform.version}'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Text("Strayker Music"),
            ),
            ListTile(
              title: const Text("Settings"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (ctxt) => const SettingsView(title: "Settings")));
              },
            ),
            ListTile(
              title: const Text("About"),
              onTap: () {
                _showMyDialog();
              },
            )
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: createControlPanelWidget(context),
          ),
          _isSearchBoxVisible ? Expanded(
            child: createBaseInputbox(_searchMusicInputController, true)
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