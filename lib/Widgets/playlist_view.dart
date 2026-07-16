import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:strayker_music/Shared/main_drawer.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key});

  @override
  State<PlaylistView> createState() => _PlaylistView();
}

class _PlaylistView extends State<PlaylistView> {
  final ScrollController _musicListScrollControl = ScrollController();
  final TextEditingController _searchMusicInputController =
      TextEditingController();
  final MainDrawer _drawer = const MainDrawer();

  @override
  void initState() {
    _searchMusicInputController.addListener(_onSearchInputChanged);
    super.initState();
  }

  void _onSearchInputChanged() {
    context
        .read<PlaylistViewModel>()
        .setSearchQuery(_searchMusicInputController.text);
  }

  @override
  void dispose() {
    _searchMusicInputController.dispose();
    _musicListScrollControl.dispose();
    super.dispose();
  }

  Future<void> _showAddToPlaylistDialog(MusicFile musicFile) async {
    final viewModel = context.read<PlaylistViewModel>();
    final playlists = await viewModel.getNamedPlaylistNames();

    if (!mounted) {
      return;
    }

    if (playlists.isEmpty) {
      _showErrorSnackBar(
        'No playlists available. Create a playlist in Settings first.',
      );
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
                final playlistName = playlists[index];

                return ListTile(
                  title: Text(playlistName),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _addSongToPlaylist(playlistName, musicFile);
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

  Future<void> _addSongToPlaylist(
    String playlistName,
    MusicFile song,
  ) async {
    try {
      await context
          .read<PlaylistViewModel>()
          .addSongToPlaylist(playlistName, song);
      if (!mounted) {
        return;
      }

      _showSuccessSnackBar('Song added to playlist successfully!');
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Failed to add song to playlist: $e');
    }
  }

  Future<void> _showRemoveFromPlaylistDialog(MusicFile musicFile) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove "${musicFile.name}" from playlist'),
          content: const Text(
            'Are you sure you want to remove this song from the current playlist?',
          ),
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
    try {
      final removed = await context
          .read<PlaylistViewModel>()
          .removeSongFromCurrentPlaylist(musicFile);
      if (!mounted) {
        return;
      }

      if (!removed) {
        _showErrorSnackBar('Cannot remove songs from "All Files" playlist.');
        return;
      }

      _showSuccessSnackBar('Song removed from playlist successfully!');
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Failed to remove song from playlist: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    _showSnackBar(message, Theme.of(context).colorScheme.error);
  }

  void _showSuccessSnackBar(String message) {
    _showSnackBar(message, Theme.of(context).colorScheme.primary);
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
        ),
      );
  }

  Row createControlPanelWidget(
    BuildContext context,
    PlaylistViewModel viewModel,
  ) {
    int index = 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: viewModel.canControlCurrentSong
              ? () {
                  final indexCalc = viewModel.songs.indexWhere(
                    (song) => song == viewModel.currentSong,
                  );
                  if (index != indexCalc) {
                    index = indexCalc;
                    final padding = MediaQuery.of(context).viewPadding;
                    _musicListScrollControl.jumpTo(
                      (index * 60) -
                          ((MediaQuery.sizeOf(context).height -
                                  padding.top -
                                  padding.bottom -
                                  kToolbarHeight) /
                              2.5),
                    );
                  } else {
                    index = 0;
                    _musicListScrollControl.jumpTo(index.toDouble());
                  }
                }
              : null,
          child: getColoredIconWidget(
            context,
            Theme.of(context).primaryTextTheme.displayMedium!.color!,
            Icons.music_note,
          ),
        ),
        ElevatedButton(
          onPressed: () {
            _searchMusicInputController.clear();
            viewModel.toggleSearch();
          },
          child: getColoredIconWidget(
            context,
            Theme.of(context).textTheme.displayLarge!.color!,
            Icons.search,
          ),
        ),
        ElevatedButton(
          onPressed:
              viewModel.canControlCurrentSong ? viewModel.resumeOrPause : null,
          child: viewModel.isPlaying && viewModel.currentSong != null
              ? getColoredIconWidget(
                  context,
                  Theme.of(context).textTheme.displayLarge!.color!,
                  Icons.pause,
                )
              : getColoredIconWidget(
                  context,
                  Theme.of(context).textTheme.displayLarge!.color!,
                  Icons.play_arrow,
                ),
        ),
        ElevatedButton(
          onPressed: viewModel.canShuffle ? viewModel.shuffle : null,
          child: getColoredIconWidget(
            context,
            Theme.of(context).textTheme.displayLarge!.color!,
            Icons.shuffle,
          ),
        ),
        if (viewModel.showsLoopControl)
          ElevatedButton(
            onPressed: viewModel.toggleLoopMode,
            child: viewModel.isLoopModeOn
                ? getColoredIconWidget(
                    context,
                    Theme.of(context).textTheme.displayLarge!.color!,
                    Icons.repeat,
                  )
                : getColoredIconWidget(
                    context,
                    Theme.of(context).textTheme.displayLarge!.color!,
                    Icons.double_arrow,
                  ),
          ),
      ],
    );
  }

  ListView createMusicListWidget(
    BuildContext context,
    PlaylistViewModel viewModel,
  ) {
    final displayedSongs = viewModel.displayedSongs;

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: displayedSongs.length,
      itemBuilder: (context, index) {
        final song = displayedSongs[index];
        return ListTile(
          minTileHeight: 60,
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: song == viewModel.currentSong
              ? getDefaultIconWidget(context, Icons.music_note)
              : null,
          onTap: () => viewModel.selectSong(song),
          onLongPress: () {
            if (viewModel.canRemoveSongs) {
              _showRemoveFromPlaylistDialog(song);
            } else {
              _showAddToPlaylistDialog(song);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlaylistViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: viewModel.currentPlaylistName ==
                PlaylistViewModel.allFilesPlaylistName
            ? const Text(Constants.appName)
            : Text(viewModel.currentPlaylistName),
      ),
      drawer: _drawer,
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
            child: createControlPanelWidget(context, viewModel),
          ),
          viewModel.isSearchVisible
              ? Expanded(
                  child: createBaseInputbox(
                    _searchMusicInputController,
                    true,
                  ),
                )
              : const SizedBox.shrink(),
          Expanded(
            flex: 10,
            child: SingleChildScrollView(
              controller: _musicListScrollControl,
              child: viewModel.songs.isNotEmpty ||
                      viewModel.displayedSongs.isNotEmpty
                  ? createMusicListWidget(context, viewModel)
                  : const Text(
                      "Welcome to Strayker Music!\n\nNo sound files can be displayed. If you think it's error, check your searching criteria, filesystem permissions and app's storage settings.",
                      softWrap: true,
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
