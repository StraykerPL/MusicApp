import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundCollectionManager {
  late final SoundPlayer _soundPlayer;
  List<MusicFile> availableSongs = [];
  List<MusicFile> playedSongs = [];
  int _playedSongsMaxAmount = 0;
  bool _loopMode = true;
  MusicFile? _currentSong;

  MusicFile? get currentSong => _currentSong;
  bool get isLoopModeOn => _loopMode;
  StreamSubscription<PlaybackState> get getPlaybackStateSubscription => _soundPlayer.getPlaybackStateSubscription();

  SoundCollectionManager({required SoundPlayer player, required List<MusicFile> songs}) {
    _soundPlayer = player;
    availableSongs = songs;
    availableSongs.sort((firstFile, secondFile) => firstFile.name.compareTo(secondFile.name));
  }

  Future<void> playRandomMusic() async {
    MusicFile randomMusicFile = _getRandomMusicFile();
    final dbContext = DatabaseHelper();
    final settings = await dbContext.getAllData(DatabaseConstants.settingsTableName);
    for (final {"name": settingName, "value": settingValue} in settings) {
      if (settingName == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        _playedSongsMaxAmount = int.parse(settingValue); 

        break;
      }
    }

    if (_playedSongsMaxAmount == 0) {
      _currentSong = randomMusicFile;
      _soundPlayer.playNewSong(_currentSong);

      return;
    }

    while (playedSongs.contains(randomMusicFile)) {
      randomMusicFile = availableSongs[Random().nextInt(availableSongs.length)];
    }

    if(playedSongs.length < _playedSongsMaxAmount) {
      playedSongs.add(randomMusicFile);
      _currentSong = randomMusicFile;
      _soundPlayer.playNewSong(_currentSong);
    }
    else if(playedSongs.length >= _playedSongsMaxAmount) {
      playedSongs.removeAt(0);
      playedSongs.add(randomMusicFile);
      _currentSong = randomMusicFile;
      _soundPlayer.playNewSong(_currentSong);
    }
  }

  void selectAndPlaySong(MusicFile song) {
    _currentSong = availableSongs.singleWhere((songFile) => songFile == song);
    _soundPlayer.playNewSong(_currentSong);
  }

  Future<void> resumeOrPauseSong() async {
    await _soundPlayer.resumeOrPauseSong();
  }

  Future<void> setLoop() async {
    _loopMode = !_loopMode;
    await _soundPlayer.setLoopMode(_loopMode);
  }

  Future<void> setLoopMode(bool enabled) async {
    _loopMode = enabled;
    await _soundPlayer.setLoopMode(_loopMode);
  }

  MusicFile _getRandomMusicFile() {
    return availableSongs[Random().nextInt(availableSongs.length)];
  }
}