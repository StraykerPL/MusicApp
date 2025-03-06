import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strayker_music/Business/database_helper.dart';
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
  DatabaseHelper? _dbContext;
  final TextEditingController _playedSongsMaxAmountInputController = TextEditingController();
  final TextEditingController _soundStorageLocationsInputController = TextEditingController();

  int _playedSongsMaxAmount = 0;
  static const int _playedSongsMaxAmountDefault = 0;
  List<String> _soundStorageLocations = [];
  static const List<String> _soundStorageLocationsDefault = ["/storage/emulated/0/Music"];
  String? _currentlySelectedStoragePath;

  void saveSettings() {
    _dbContext!.updateDataByName("settings", "playedSongsMaxAmount", {"value": _playedSongsMaxAmount});
    
    List<Map<String, dynamic>> sumUpData = [];
    for (var storagePath in _soundStorageLocations) {
      sumUpData.add({"name": storagePath});
    }

    _dbContext!.cleanTable("storageLocations").then((voidArg)  {
      _dbContext!.insertData("storageLocations", sumUpData);
    });
  }

  void loadSettings() {
    _dbContext!.getAllData("settings").then((settingsRawData) {
      for (var row in settingsRawData) {
        if (row["name"] == "playedSongsMaxAmount") {
          _playedSongsMaxAmount = int.parse(row["value"]);
          _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
            text: _playedSongsMaxAmount.toString(),
            selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
          );
        }
      }
    });

    _dbContext!.getAllData("storageLocations").then((storageLocationsRawData) {
      for (final {"name": name as String} in storageLocationsRawData) {
        if (!_soundStorageLocations.contains(name)) {
          setState(() {
            _soundStorageLocations.add(name);
          });
        }
      }
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
                  loadSettings();
                  setState(() {
                    _soundStorageLocationsInputController.value = _soundStorageLocationsInputController.value.copyWith(text: Constants.stringEmpty);
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
    );
  }
}