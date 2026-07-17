import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Services/database_helper.dart';

class SettingsSnapshotRepository {
  SettingsSnapshotRepository({required DatabaseHelper databaseHelper})
      : _databaseHelper = databaseHelper;

  final DatabaseHelper _databaseHelper;

  Future<SettingsSnapshot> get() async {
    final setting = await _databaseHelper.queryPlayedSongsMaxAmount();
    final value = int.tryParse(setting?['value'].toString() ?? '') ??
        DatabaseConstants.playedSongsMaxAmountDefault;
    return SettingsSnapshot(
      playedSongsMaxAmount: value,
      storageLocations: await _databaseHelper.queryStorageLocations(),
    );
  }

  Future<void> save(SettingsSnapshot snapshot) {
    return _databaseHelper.replaceSettingsData(
      playedSongsMaxAmount: snapshot.playedSongsMaxAmount,
      storageLocations: snapshot.storageLocations,
    );
  }

  Future<void> updatePlayedSongsMaxAmount(int value) {
    return _databaseHelper.updatePlayedSongsMaxAmount(value);
  }
}
