import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/get_default_icon_widget.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.title});
  final String title;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Database? _dbContext;
  final StoreRef<String, Map<String, Object?>> _settingsStore = stringMapStoreFactory.store('settings');
  final TextEditingController _playedSongsMaxAmountInputController = TextEditingController();
  final TextEditingController _soundStorageLocationsInputController = TextEditingController();

  int _playedSongsMaxAmount = 0;
  static const int _playedSongsMaxAmountDefault = 0;
  List<String> _soundStorageLocations = ["/storage/emulated/0/MicroSD/Muzyka", "/storage/emulated/0/MicroSD/Muzyka One Republic"];
  static const List<String> _soundStorageLocationsDefault = [];
  String? _currentlySelectedStoragePath;

  String serializeList(List<String> collection) {
    var newString = "";

    for (var stringToConcat in collection) {
      newString += stringToConcat;
      newString += ";";
    }

    return newString;
  }

  List<String> deserializeString(String serializedValue) {
    return serializedValue.split(";");
  }

  void saveSettings() {
    _settingsStore.record("playedSongsMaxAmount").put(_dbContext!, { "value": _playedSongsMaxAmount });
    _settingsStore.record("soundStorageLocations").put(_dbContext!, { "values": serializeList(_soundStorageLocations) });
  }

  void loadSettings() {
    _settingsStore.record('playedSongsMaxAmount').get(_dbContext!).then((maxAmount) {
      _playedSongsMaxAmount = maxAmount!.values.first as int;
    });
    _settingsStore.record('soundStorageLocations').get(_dbContext!).then((locations) {
      _soundStorageLocations = deserializeString(locations!.values.first as String);
    });
  }

  void setDefualtValues() {
    _playedSongsMaxAmount = _playedSongsMaxAmountDefault;
    _soundStorageLocations = _soundStorageLocationsDefault;

    saveSettings();
  }

  @override
  void initState() {
    super.initState();
    File dbFile = File("/storage/emulated/0/strayker_music.db");
    dbFile.exists().onError((obj, stack) {
      dbFile.createSync();

      return false;
    });

    databaseFactoryIo.openDatabase(dbFile.path).then((db) {
      _dbContext = db;

      _settingsStore.record("playedSongsMaxAmount").exists(_dbContext!).then((value) => {
        if(!value) {
          _settingsStore.record("playedSongsMaxAmount").put(_dbContext!, { "value": _playedSongsMaxAmountDefault }),
          _settingsStore.record("soundStorageLocations").put(_dbContext!, { "values": _soundStorageLocationsDefault })
        }
        else {
          setState(() {
            loadSettings();
          }),
          _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
            text: _playedSongsMaxAmount.toString(),
            selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
          )
        }
      });
    });
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
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          const Text("Amount of repetitive songs prevention queue:"),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _playedSongsMaxAmountInputController,
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number
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
                      onPressed: () => {
                        if (_soundStorageLocationsInputController.value.text != Constants.stringEmpty) {
                          setState(() {
                            _soundStorageLocations.add(_soundStorageLocationsInputController.value.text);
                          }),
                          _soundStorageLocationsInputController.clear()
                        }
                      },
                      child: const Text("+")
                    ),
                    ElevatedButton(
                      onPressed: () => {
                        setState(() {
                          _soundStorageLocations.remove(_currentlySelectedStoragePath);
                        }),
                        _currentlySelectedStoragePath = null
                      },
                      child: const Text("-")
                    ),
                  ],
                ),
                createBaseInputbox(_soundStorageLocationsInputController, false),
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
                child: const Text("Save")
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    loadSettings();
                    _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
                      text: _playedSongsMaxAmount.toString(),
                      selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
                    );
                    _soundStorageLocationsInputController.value = _soundStorageLocationsInputController.value.copyWith(text: Constants.stringEmpty);
                  });
                },
                child: const Text("Cancel")
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    setDefualtValues();
                    _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
                      text: _playedSongsMaxAmount.toString(),
                      selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
                    );
                    _soundStorageLocationsInputController.value = _soundStorageLocationsInputController.value.copyWith(text: Constants.stringEmpty);
                  });
                },
                child: const Text("Load Default")
              )
            ],
          )
        ]
      ),
    );
  }
}