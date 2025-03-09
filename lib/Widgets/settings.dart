import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Shared/create_search_inputbox.dart';
import 'package:strayker_music/Shared/get_default_icon_widget.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.title});
  final String title;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  DatabaseHelper? _dbContext;
  final TextEditingController _playedSongsMaxAmountInputController = TextEditingController();
  final TextEditingController _soundStorageLocationsInputController = TextEditingController();

  int _playedSongsMaxAmount = 0;
  List<String> _soundStorageLocations = [];
  String? _currentlySelectedStoragePath;

  Future<void> saveSettings() async {
    await _dbContext!.updateDataByName(
      DatabaseConstants.settingsTableName,
      DatabaseConstants.playedSongsMaxAmountTableValueName,
      {"value": _playedSongsMaxAmount});
    
    List<Map<String, dynamic>> sumUpData = [];
    for (var storagePath in _soundStorageLocations) {
      sumUpData.add({"name": storagePath});
    }

    await _dbContext!.cleanTable(DatabaseConstants.storagePathsTableName);
    await _dbContext!.insertData(DatabaseConstants.storagePathsTableName, sumUpData);
  }

  Future<void> loadSettings() async {
    var settingsRawData = await _dbContext!.getAllData(DatabaseConstants.settingsTableName);
    for (var row in settingsRawData) {
      if (row["name"] == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        _playedSongsMaxAmount = int.parse(row["value"]);
        _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
          text: _playedSongsMaxAmount.toString(),
          selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
        );
      }
    }

    var storageLocationsRawData = await _dbContext!.getAllData(DatabaseConstants.storagePathsTableName);
    setState(() {
      for (final {"name": name as String} in storageLocationsRawData) {
        if (!_soundStorageLocations.contains(name)) {
          _soundStorageLocations.add(name);
        }
      }
    });
  }

  void setDefualtValues() {
    _playedSongsMaxAmount = DatabaseConstants.playedSongsMaxAmountDefault;
    _soundStorageLocations = DatabaseConstants.soundStorageLocationsDefault;

    saveSettings();
  }

  @override
  void initState() {
    super.initState();
    _dbContext = DatabaseHelper();
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
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("Amount of repetitive songs prevention queue\n(zero means this feature is disabled):"),
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
                    loadSettings();
                    setState(() {
                      _soundStorageLocationsInputController.value = _soundStorageLocationsInputController.value.copyWith(text: Constants.stringEmpty);
                      _currentlySelectedStoragePath = null;
                    });
                  },
                  child: const Text("Cancel")
                ),
                ElevatedButton(
                  onPressed: () {
                    setDefualtValues();
                    setState(() {
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
      )
    );
  }
}