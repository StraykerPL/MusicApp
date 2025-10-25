import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:strayker_music/Shared/main_drawer.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key, required this.title});
  final String title;

  @override
  State<PlaylistView> createState() => _PlaylistView();
}

class _PlaylistView extends State<PlaylistView> {
  final ScrollController _musicListScrollControl = ScrollController();
  final TextEditingController _searchMusicInputController = TextEditingController();

  bool _isCurrentlyPlaying = false;
  bool _isSearchBoxVisible = false;
  bool _isLoopModeOn = true;
  late List<MusicFile> displayedFiles = [];
  late final SoundCollectionManager _soundCollectionManager = SoundCollectionManager(player: context.read<SoundPlayer>(), songs: context.read<List<MusicFile>>());

  _PlaylistView() {
    _searchMusicInputController.addListener(onSearchInputChanged);
  }

  @override
  void initState() {
    _soundCollectionManager.getPlaybackStateSubscription.onData((value) {
      if (value.processingState == AudioProcessingState.completed && context.read<PlaylistManager>().currentPlaylist != "All Files" && _isLoopModeOn) {
        var index = _soundCollectionManager.availableSongs.indexOf(_soundCollectionManager.currentSong!);
        _soundCollectionManager.selectAndPlaySong(_soundCollectionManager.availableSongs[index]);
      }
      setState(() {
        _isCurrentlyPlaying = value.playing;
      });
    });
    displayedFiles = _soundCollectionManager.availableSongs;
    _isLoopModeOn = _soundCollectionManager.isLoopModeOn;
    super.initState();
  }

  List<MusicFile> _filterFiles(List<MusicFile> files) {
    List<MusicFile> filteredFiles = [];

    for (var soundFile in files) {
      if (soundFile.name.toUpperCase().contains(_searchMusicInputController.value.text.toUpperCase())) {
        filteredFiles.add(soundFile);
      }
    }

    return filteredFiles;
  }

  Future<void> onSearchInputChanged() async {
    if (_searchMusicInputController.value.text == Constants.stringEmpty) {
      setState(() {
        displayedFiles = _soundCollectionManager.availableSongs;
      });

      return;
    }

    setState(() {
      displayedFiles = _filterFiles(displayedFiles);
    });
  }

  @override
  void dispose() {
    _searchMusicInputController.dispose();
    super.dispose();
  }

  Future<void> _showAddToPlaylistDialog(MusicFile musicFile) async {
    final playlistManager = context.read<PlaylistManager>();
    final playlists = await playlistManager.getPlaylists();
    
    if (playlists.isEmpty) {
      _showErrorDialog('No playlists available. Create a playlist in Settings first.');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add "${musicFile.name}" to playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final playlistName = playlist['name'] as String;
                
                return ListTile(
                  title: Text(playlistName),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _addSongToPlaylist(playlistName, musicFile.filePath);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSongToPlaylist(String playlistName, String songPath) async {
    try {
      final playlistManager = context.read<PlaylistManager>();
      await playlistManager.addSongToPlaylistByName(playlistName, songPath);
      _showSuccessDialog('Song added to playlist successfully!');
    } catch (e) {
      _showErrorDialog('Failed to add song to playlist: $e');
    }
  }

  Future<void> _showRemoveFromPlaylistDialog(MusicFile musicFile) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove "${musicFile.name}" from playlist'),
          content: const Text('Are you sure you want to remove this song from the current playlist?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _removeSongFromPlaylist(musicFile);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeSongFromPlaylist(MusicFile musicFile) async {
    if (context.read<PlaylistManager>().currentPlaylist == "All Files") {
      _showErrorDialog('Cannot remove songs from "All Files" playlist.');
      return;
    }

    try {
      final playlistManager = context.read<PlaylistManager>();
      await playlistManager.removeSongFromPlaylistByName(
        context.read<PlaylistManager>().currentPlaylist, 
        musicFile.filePath
      );
      
      setState(() {
        displayedFiles = _soundCollectionManager.availableSongs;
      });
      
      _showSuccessDialog('Song removed from playlist successfully!');
    } catch (e) {
      _showErrorDialog('Failed to remove song from playlist: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Row createControlPanelWidget(BuildContext context) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _isCurrentlyPlaying || _soundCollectionManager.currentSong != null ? () {
            var indexCalc = _soundCollectionManager.availableSongs.indexWhere((song) => song == _soundCollectionManager.currentSong);
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
          onPressed: _isCurrentlyPlaying || _soundCollectionManager.currentSong != null ? () => _soundCollectionManager.resumeOrPauseSong() : null,
          child: _isCurrentlyPlaying && _soundCollectionManager.currentSong != null ?
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.pause) :
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () {
            _soundCollectionManager.playRandomMusic();
          },
          child: getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.shuffle),
        ),
        if (context.read<PlaylistManager>().currentPlaylist != "All Files")
          ElevatedButton(
            onPressed: () {
              _soundCollectionManager.setLoop();
              setState(() {
                _isLoopModeOn = _soundCollectionManager.isLoopModeOn;
              });
            },
            child: _isLoopModeOn ? getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.repeat) : getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.double_arrow),
          ),
      ],
    );
  }

  ListView createMusicListWidget(BuildContext context) {
    // if (context.read<PlaylistManager>().currentPlaylistSongs.isEmpty == false) {
    //   _soundCollectionManager.availableSongs = context.read<PlaylistManager>().currentPlaylistSongs;
    // }
    // else if (context.read<PlaylistManager>().currentPlaylistSongs.isEmpty == true && context.read<PlaylistManager>().currentPlaylist == "All Files") {
    //   _soundCollectionManager.availableSongs = context.read<List<MusicFile>>();
    // }
    // else if (context.read<PlaylistManager>().currentPlaylistSongs.isEmpty == false && context.read<PlaylistManager>().currentPlaylist != "All Files") {
    //   _soundCollectionManager.availableSongs = context.read<PlaylistManager>().currentPlaylistSongs;
    // }
    // else {
    //   _soundCollectionManager.availableSongs = [];
    // }
    if (context.read<PlaylistManager>().currentPlaylist == "All Files") {
      _soundCollectionManager.availableSongs = context.read<List<MusicFile>>();
    }
    else {
      _soundCollectionManager.availableSongs = context.read<PlaylistManager>().currentPlaylistSongs;
    }
    displayedFiles = _filterFiles(_soundCollectionManager.availableSongs);

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
          trailing: displayedFiles[index] == _soundCollectionManager.currentSong ?
            getDefaultIconWidget(context, Icons.music_note) : null,
          onTap: () => {
            _soundCollectionManager.selectAndPlaySong(displayedFiles[index])
          },
          onLongPress: () {
            if (context.read<PlaylistManager>().currentPlaylist == "All Files") {
              _showAddToPlaylistDialog(displayedFiles[index]);
            } else {
              _showRemoveFromPlaylistDialog(displayedFiles[index]);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.read<PlaylistManager>(),
      builder: (BuildContext ctx, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(ctx).colorScheme.primary,
            title: ctx.read<PlaylistManager>().currentPlaylist == "All Files" ? const Text(Constants.appName) : Text(ctx.read<PlaylistManager>().currentPlaylist),
          ),
          drawer: const MainDrawer(),
          body: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 60,
                child: createControlPanelWidget(ctx),
              ),
              _isSearchBoxVisible ? Expanded(
                child: createBaseInputbox(_searchMusicInputController, true)
              ) as Widget : const SizedBox.shrink(),
              Expanded(
                flex: 10,
                child: SingleChildScrollView(
                  controller: _musicListScrollControl,
                  child: 
                  context.read<PlaylistManager>().currentPlaylistSongs.isNotEmpty || displayedFiles.isNotEmpty || _soundCollectionManager.availableSongs.isNotEmpty ?
                    createMusicListWidget(ctx) :
                    const Text("Welcome to Strayker Music!\n\nNo sound files can be displayed. If you think it's error, check your searching criteria, filesystem permissions and app's storage settings.", softWrap: true, textAlign: TextAlign.center),
                )
              )
            ],
          )
        );
      }
    );
  }
}