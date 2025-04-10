import 'dart:math';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/constants.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundCollectionManager {
  late final SoundPlayer _soundPlayer;
  List<MusicFile> availableSongs = [];
  List<MusicFile> playedSongs = [];
  int _playedSongsMaxAmount = 0;
  String currentSong = Constants.stringEmpty;

  SoundCollectionManager({required SoundPlayer player, required List<MusicFile> songs}) {
    _soundPlayer = player;
    availableSongs = songs;
    availableSongs.sort((firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
  }

  Future<void> playRandomMusic() async {
    while (true) {
      MusicFile randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];
      final dbContext = DatabaseHelper();
      final settings = await dbContext.getAllData(DatabaseConstants.settingsTableName);
      for (final {"name": settingName, "value": settingValue} in settings) {
        if (settingName == DatabaseConstants.playedSongsMaxAmountTableValueName) {
          _playedSongsMaxAmount = int.parse(settingValue); 
        }
      }

      if (_playedSongsMaxAmount == 0) {
        _soundPlayer.currentSong = randomMusicFile;
        currentSong = randomMusicFile.name;
        _soundPlayer.playNewSong();
        break;
      }

      if(!playedSongs.contains(randomMusicFile)) {
        if(playedSongs.length < _playedSongsMaxAmount) {
          playedSongs.add(randomMusicFile);
          _soundPlayer.currentSong = randomMusicFile;
          currentSong = randomMusicFile.name;
          _soundPlayer.playNewSong();
          break;
        }
        else if(playedSongs.length >= _playedSongsMaxAmount) {
          playedSongs.removeAt(0);
          playedSongs.add(randomMusicFile);
          _soundPlayer.currentSong = randomMusicFile;
          currentSong = randomMusicFile.name;
          _soundPlayer.playNewSong();
          break;
        }
      }
      else {
        randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];
      }
    }
  }

  void selectAndPlaySong(String songName) {
    _soundPlayer.currentSong = availableSongs.singleWhere((songFile) => songFile.name == songName);
    currentSong = _soundPlayer.currentSong!.name;
    _soundPlayer.playNewSong();
  }
}