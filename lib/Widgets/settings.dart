import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

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

  int _playedSongsMaxAmount = 20;
  static const int _playedSongsMaxAmountDefault = 20;
  List<String> _soundStorageLocations = ["/storage/emulated/0/MicroSD/Muzyka", "/storage/emulated/0/MicroSD/Muzyka One Republic"];
  static const List<String> _soundStorageLocationsDefault = [];

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
          _settingsStore.record('playedSongsMaxAmount').get(_dbContext!).then((maxAmount) {
            _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
              text: maxAmount!.values.first.toString(),
              selection: TextSelection.collapsed(offset: maxAmount.toString().length),
            );
          }),
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
          onTap: () => {},
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
                const Row(
                  children: [
                    ElevatedButton(onPressed: null, child: Text("+")),
                    ElevatedButton(onPressed: null, child: Text("-")),
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
              const ElevatedButton(
                onPressed: null,
                child: Text("Save")
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
                      text: _playedSongsMaxAmount.toString(),
                      selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
                    );
                    _soundStorageLocationsInputController.value = _soundStorageLocationsInputController.value.copyWith(text: "");
                  });
                },
                child: const Text("Cancel")
              ),
              ElevatedButton(
                onPressed: () {
                  _settingsStore.record("playedSongsMaxAmount").update(_dbContext!, { "value": _playedSongsMaxAmountDefault });
                  _settingsStore.record("soundStorageLocations").update(_dbContext!, { "values": _soundStorageLocationsDefault });
                  _playedSongsMaxAmountInputController.value = _playedSongsMaxAmountInputController.value.copyWith(
                    text: _playedSongsMaxAmount.toString(),
                    selection: TextSelection.collapsed(offset: _playedSongsMaxAmount.toString().length),
                  );
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