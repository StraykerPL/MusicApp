import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Shared/icon_widgets.dart';
import 'package:filesystem_picker/filesystem_picker.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final DatabaseHelper _dbContext = DatabaseHelper();
  final TextEditingController _playedSongsMaxAmountInputController = TextEditingController();

  int _playedSongsMaxAmount = 0;
  List<String> _soundStorageLocations = [];
  String? _currentlySelectedStoragePath;

  Future<void> saveSettings() async {
    await _dbContext.updateDataByName(
      DatabaseConstants.settingsTableName,
      DatabaseConstants.playedSongsMaxAmountTableValueName,
      {"value": _playedSongsMaxAmount});
    
    List<Map<String, dynamic>> sumUpData = [];
    for (var storagePath in _soundStorageLocations) {
      sumUpData.add({"name": storagePath});
    }

    await _dbContext.cleanTable(DatabaseConstants.storagePathsTableName);
    await _dbContext.insertData(DatabaseConstants.storagePathsTableName, sumUpData);
  }

  Future<void> loadSettings() async {
    var settingsRawData = await _dbContext.getAllData(DatabaseConstants.settingsTableName);
    for (var row in settingsRawData) {
      if (row["name"] == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        _playedSongsMaxAmount = int.parse(row["value"]);
        _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
          text: _playedSongsMaxAmount.toString(),
          selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
        );
      }
    }

    var storageLocationsRawData = await _dbContext.getAllData(DatabaseConstants.storagePathsTableName);
    for (final {"name": name as String} in storageLocationsRawData) {
      if (!_soundStorageLocations.contains(name)) {
        setState(() {
          _soundStorageLocations.add(name);
        });
      }
    }
  }

  void setDefualtValues() {
    _playedSongsMaxAmount = DatabaseConstants.playedSongsMaxAmountDefault;
    _soundStorageLocations = DatabaseConstants.soundStorageLocationsDefault;

    saveSettings();
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
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