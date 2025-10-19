import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:filesystem_picker/filesystem_picker.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _playedSongsMaxAmountInputController = TextEditingController();
  final TextEditingController _newPlaylistNameController = TextEditingController();

  int _playedSongsMaxAmount = 0;
  bool _loopMode = true;
  List<String> _soundStorageLocations = [];
  String? _currentlySelectedStoragePath;
  List<Map<String, dynamic>> _playlists = [];
  String? _currentlySelectedPlaylist;

  Future<void> saveSettings() async {
    final dbContext = context.read<DatabaseHelper>();
    await dbContext.updateDataByName(
      DatabaseConstants.settingsTableName,
      DatabaseConstants.playedSongsMaxAmountTableValueName,
      {"value": _playedSongsMaxAmount});
    
    await dbContext.updateDataByName(
      DatabaseConstants.settingsTableName,
      DatabaseConstants.loopModeTableValueName,
      {"value": _loopMode ? "true" : "false"});
    
    List<Map<String, dynamic>> sumUpData = [];
    for (var storagePath in _soundStorageLocations) {
      sumUpData.add({"name": storagePath});
    }

    await dbContext.cleanTable(DatabaseConstants.storagePathsTableName);
    await dbContext.insertData(DatabaseConstants.storagePathsTableName, sumUpData);
  }

  Future<void> loadSettings() async {
    final dbContext = context.read<DatabaseHelper>();
    final playlistManager = context.read<PlaylistManager>();
    
    var settingsRawData = await dbContext.getAllData(DatabaseConstants.settingsTableName);
    for (var row in settingsRawData) {
      if (row["name"] == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        _playedSongsMaxAmount = int.parse(row["value"]);
        _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
          text: _playedSongsMaxAmount.toString(),
          selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
        );
      }
      if (row["name"] == DatabaseConstants.loopModeTableValueName) {
        _loopMode = row["value"] == "true";
      }
    }

    var storageLocationsRawData = await dbContext.getAllData(DatabaseConstants.storagePathsTableName);
    for (final {"name": name as String} in storageLocationsRawData) {
      if (!_soundStorageLocations.contains(name)) {
        setState(() {
          _soundStorageLocations.add(name);
        });
      }
    }

    _playlists = await playlistManager.getPlaylists();
  }

  void setDefualtValues() {
    _playedSongsMaxAmount = DatabaseConstants.playedSongsMaxAmountDefault;
    _loopMode = DatabaseConstants.loopModeDefault;
    _soundStorageLocations = DatabaseConstants.soundStorageLocationsDefault;

    saveSettings();
  }

  Future<void> createPlaylist() async {
    if (_newPlaylistNameController.text.trim().isEmpty) {
      return;
    }

    final playlistName = _newPlaylistNameController.text.trim();
    
    // Check if playlist already exists
    if (_playlists.any((playlist) => playlist['name'] == playlistName)) {
      _showErrorDialog('Playlist "$playlistName" already exists!');
      return;
    }

    try {
      final playlistManager = context.read<PlaylistManager>();
      await playlistManager.createPlaylist(playlistName);
      _newPlaylistNameController.clear();
      await loadSettings();
      setState(() {});
    } catch (e) {
      _showErrorDialog('Failed to create playlist: $e');
    }
  }

  Future<void> deletePlaylist() async {
    if (_currentlySelectedPlaylist == null) {
      return;
    }

    final playlist = _playlists.firstWhere(
      (p) => p['name'] == _currentlySelectedPlaylist,
      orElse: () => {'id': -1, 'name': ''},
    );

    if (playlist['id'] == -1) {
      return;
    }

    try {
      final playlistManager = context.read<PlaylistManager>();
      await playlistManager.deletePlaylist(playlist['id']);
      _currentlySelectedPlaylist = null;
      await loadSettings();
      setState(() {});
    } catch (e) {
      _showErrorDialog('Failed to delete playlist: $e');
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

  @override
  void initState() {
    loadSettings();
    super.initState();
  }

  @override
  void dispose() {
    _newPlaylistNameController.dispose();
    super.dispose();
  }

  ListView createPathsListWidget(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _soundStorageLocations.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(
            _soundStorageLocations[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: _currentlySelectedStoragePath == _soundStorageLocations[index] ?
            getDefaultIconWidget(context, Icons.check) : null,
          onTap: () => {
            setState(() {
              _currentlySelectedStoragePath = _soundStorageLocations[index];
            })
          },
        );
      },
    );
  }

  ListView createPlaylistsListWidget(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        final playlistName = playlist['name'] as String;
        final isAllFiles = playlistName == "All Files";
        
        return ListTile(
          title: Text(
            playlistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          trailing: _currentlySelectedPlaylist == playlistName ?
            getDefaultIconWidget(context, Icons.check) : null,
          onTap: isAllFiles ? null : () => {
            setState(() {
              _currentlySelectedPlaylist = playlistName;
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
        title: const Text("Settings"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            const Text("Amount of repetitive songs prevention queue\n(zero means this feature is disabled):", textAlign: TextAlign.center,),
            SizedBox(
              width: 50,
              child: TextField(
                controller: _playedSongsMaxAmountInputController,
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                keyboardType: TextInputType.number
                // TODO: Add validation to not allow input of number surpassing max amount of available sound files.
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Loop playlist (replay in circle):"),
                Switch(
                  value: _loopMode,
                  onChanged: (value) {
                    setState(() {
                      _loopMode = value;
                    });
                  },
                ),
              ],
            ),
            const Text("Storage paths to look for sound files:"),
            SizedBox(
              width: double.infinity,
              height: 300,
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // TODO: Add validation to not allow access to restricted areas of filesystem.
                          var ok = await FilesystemPicker.open(
                            title: 'Folder Select',
                            context: context,
                            rootDirectory: Directory.fromUri(Uri(path: "/storage/emulated/0")),
                            fsType: FilesystemType.folder,
                            pickText: 'Add selected folder',
                          );
                          if (ok != null) {
                            setState(() {
                              _soundStorageLocations.add(ok);
                            });
                          }
                        },
                        child: Text("+", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                      ),
                      ElevatedButton(
                        onPressed: () => {
                          setState(() {
                            _soundStorageLocations.remove(_currentlySelectedStoragePath);
                          }),
                          _currentlySelectedStoragePath = null
                        },
                        child: Text("-", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    child: createPathsListWidget(context),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Playlist Management:"),
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _newPlaylistNameController,
                          decoration: const InputDecoration(
                            hintText: "Enter playlist name",
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => createPlaylist(),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: createPlaylist,
                        child: Text("Create", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                      ),
                      ElevatedButton(
                        onPressed: _currentlySelectedPlaylist != null && _currentlySelectedPlaylist != "All Files" ? deletePlaylist : null,
                        child: Text("Delete", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: createPlaylistsListWidget(context),
                    ),
                  )
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _playedSongsMaxAmount = int.parse(_playedSongsMaxAmountInputController.value.text);
                    saveSettings();
                  },
                  child: Text("Save", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                ),
                ElevatedButton(
                  onPressed: () {
                    loadSettings();
                    setState(() {
                      _currentlySelectedStoragePath = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                ),
                ElevatedButton(
                  onPressed: () {
                    setDefualtValues();
                    setState(() {
                      _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
                        text: _playedSongsMaxAmount.toString(),
                        selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
                      );
                    });
                  },
                  child: Text("Load Default", style: TextStyle(color: Theme.of(context).textTheme.displayLarge?.color))
                )
              ],
            )
          ]
        ),
      )
    );
  }
}