import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:strayker_music/Shared/main_drawer.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key, required this.title, required this.soundCollectionManager});
  final String title;
  final SoundCollectionManager soundCollectionManager;

  @override
  State<PlaylistView> createState() => _PlaylistView();
}

class _PlaylistView extends State<PlaylistView> {
  final ScrollController _musicListScrollControl = ScrollController();
  final TextEditingController _searchMusicInputController = TextEditingController();

  late final StreamSubscription<bool> _isPlayingSubscription;
  bool _isCurrentlyPlaying = false;
  bool _isSearchBoxVisible = false;
  late List<MusicFile> displayedFiles = [];

  _PlaylistView() {
    _searchMusicInputController.addListener(onSearchInputChanged);
  }

  @override
  void initState() {
    widget.soundCollectionManager.getPlaybackStateSubscription.onData((value) {
      setState(() {
        _isCurrentlyPlaying = value.playing;
      });
    });
    displayedFiles = widget.soundCollectionManager.availableSongs;
    super.initState();
  }

  Future<void> onSearchInputChanged() async {
    if (_searchMusicInputController.value.text == Constants.stringEmpty) {
      setState(() {
        displayedFiles = widget.soundCollectionManager.availableSongs;
      });
    }

    List<MusicFile> filteredFiles = [];
    for (var soundFile in widget.soundCollectionManager.availableSongs) {
      if (soundFile.name.toUpperCase().contains(_searchMusicInputController.value.text.toUpperCase())) {
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
    _isPlayingSubscription.cancel();
    super.dispose();
  }

  Row createControlPanelWidget(BuildContext context) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _isCurrentlyPlaying || widget.soundCollectionManager.currentSong != null ? () {
            var indexCalc = widget.soundCollectionManager.availableSongs.indexWhere((song) => song == widget.soundCollectionManager.currentSong);
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
          } : null,
          child: getColoredIconWidget(context, Theme.of(context).primaryTextTheme.displayMedium!.color!, Icons.music_note),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _searchMusicInputController.clear();
              _isSearchBoxVisible = !_isSearchBoxVisible;
            });
          },
          child: getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.search),
        ),
        ElevatedButton(
          onPressed: _isCurrentlyPlaying || widget.soundCollectionManager.currentSong != null ? () => widget.soundCollectionManager.resumeOrPauseSong() : null,
          child: _isCurrentlyPlaying && widget.soundCollectionManager.currentSong != null ?
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.pause) :
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () {
            widget.soundCollectionManager.playRandomMusic();
          },
          child: getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.shuffle),
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
          trailing: displayedFiles[index] == widget.soundCollectionManager.currentSong ?
            getDefaultIconWidget(context, Icons.music_note) : null,
          onTap: () => {
            widget.soundCollectionManager.selectAndPlaySong(displayedFiles[index])
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
      drawer: context.watch<MainDrawer>(),
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
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
                const Text("Welcome to Strayker Music!\n\nNo sound files can be displayed. If you think it's error, check your searching criteria, filesystem permissions and app's storage settings.", softWrap: true, textAlign: TextAlign.center),
            )
          )
        ],
      )
    );
  }
}