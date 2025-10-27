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
  const PlaylistView({super.key});

  @override
  State<PlaylistView> createState() => _PlaylistView();
}

class _PlaylistView extends State<PlaylistView> {
  final ScrollController _musicListScrollControl = ScrollController();
  final TextEditingController _searchMusicInputController = TextEditingController();

  bool _isCurrentlyPlaying = false;
  bool _isSearchBoxVisible = false;
  bool _isLoopModeOn = false;
  List<MusicFile> _displayedFiles = [];
  MusicFile? _currentSong;
  late final SoundCollectionManager _soundCollectionManager = SoundCollectionManager(player: context.read<SoundPlayer>());
  late final PlaylistManager _playlistManager = context.read<PlaylistManager>();

  @override
  void initState() {
    _soundCollectionManager.setLoopMode(true);
    _searchMusicInputController.addListener(onSearchInputChanged);
    _soundCollectionManager.getPlaybackStateSubscription.onData((value) {
      if (_playlistManager.currentPlaylist != "All Files") {
        if (value.processingState == AudioProcessingState.completed) {
          if (!_isLoopModeOn) {
            setState(() {
              _currentSong = _playlistManager.getNextSongFromPlaylist(_currentSong!);
            });
          }

          _soundCollectionManager.selectAndPlaySong(_currentSong!);
        }
      }

      setState(() {
        _isCurrentlyPlaying = value.playing;
      });
    });
    _displayedFiles = _playlistManager.currentPlaylistSongs;
    _playlistManager.addListener(() async {
      if (_playlistManager.currentPlaylist == "All Files") {
        await _soundCollectionManager.setLoopMode(true);
      }
      else {
        await _soundCollectionManager.setLoopMode(_isLoopModeOn);
      }
    });
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
        _displayedFiles = _playlistManager.currentPlaylistSongs;
      });

      return;
    }

    setState(() {
      _displayedFiles = _filterFiles(_displayedFiles);
    });
  }

  @override
  void dispose() {
    _searchMusicInputController.dispose();
    _playlistManager.dispose();
    super.dispose();
  }

  Future<void> _showAddToPlaylistDialog(MusicFile musicFile) async {
    final playlists = await context.read<PlaylistManager>().getPlaylists();
    
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
      await context.read<PlaylistManager>().addSongToPlaylistByName(playlistName, songPath);
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
      await context.read<PlaylistManager>().removeSongFromPlaylistByName(
        context.read<PlaylistManager>().currentPlaylist, 
        musicFile.filePath
      );
      
      setState(() {
        _displayedFiles = _playlistManager.currentPlaylistSongs;
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
          onPressed: _isCurrentlyPlaying || _currentSong != null ? () {
            var indexCalc = _playlistManager.currentPlaylistSongs.indexWhere((song) => song == _currentSong);
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
          onPressed: _isCurrentlyPlaying || _currentSong != null ? () => _soundCollectionManager.resumeOrPauseSong() : null,
          child: _isCurrentlyPlaying && _currentSong != null ?
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.pause) :
            getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.play_arrow)
        ),
        ElevatedButton(
          onPressed: () async {
            var song = await _soundCollectionManager.playRandomMusic(_playlistManager.currentPlaylistSongs);
            setState(()  {
              _currentSong = song;
            });
          },
          child: getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.shuffle),
        ),
        if (context.read<PlaylistManager>().currentPlaylist != "All Files")
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _isLoopModeOn = !_isLoopModeOn;
              });
              await _soundCollectionManager.setLoopMode(_isLoopModeOn);
            },
            child: _isLoopModeOn ?
              getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.repeat) :
              getColoredIconWidget(context, Theme.of(context).textTheme.displayLarge!.color!, Icons.double_arrow),
          ),
      ],
    );
  }

  ListView createMusicListWidget(BuildContext context) {
    _displayedFiles = _filterFiles(_playlistManager.currentPlaylistSongs);

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _displayedFiles.length,
      itemBuilder: (context, index) {
        return ListTile(
          minTileHeight: 60,
          title: Text(
            _displayedFiles[index].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: _displayedFiles[index] == _currentSong ?
            getDefaultIconWidget(context, Icons.music_note) : null,
          onTap: () => {
            _currentSong = _displayedFiles[index],
            _soundCollectionManager.selectAndPlaySong(_displayedFiles[index])
          },
          onLongPress: () {
            if (context.read<PlaylistManager>().currentPlaylist == "All Files") {
              _showAddToPlaylistDialog(_displayedFiles[index]);
            } else {
              _showRemoveFromPlaylistDialog(_displayedFiles[index]);
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
                  context.read<PlaylistManager>().currentPlaylistSongs.isNotEmpty || _displayedFiles.isNotEmpty || _playlistManager.currentPlaylistSongs.isNotEmpty ?
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