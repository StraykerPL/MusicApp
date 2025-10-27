import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundCollectionManager {
  late final SoundPlayer _soundPlayer;
  final List<MusicFile> _playedSongs = [];
  int _playedSongsMaxAmount = 0;

  StreamSubscription<PlaybackState> get getPlaybackStateSubscription => _soundPlayer.getPlaybackStateSubscription();

  SoundCollectionManager({required SoundPlayer player}) {
    _soundPlayer = player;
  }

  Future<MusicFile> playRandomMusic(List<MusicFile> availableSongs) async {
    MusicFile randomMusicFile = _getRandomMusicFile(availableSongs);
    final dbContext = DatabaseHelper();
    final settings = await dbContext.getAllData(DatabaseConstants.settingsTableName);
    for (final {"name": settingName, "value": settingValue} in settings) {
      if (settingName == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        _playedSongsMaxAmount = int.parse(settingValue); 

        break;
      }
    }

    if (_playedSongsMaxAmount == 0) {
      await _soundPlayer.playNewSong(randomMusicFile);

      return randomMusicFile;
    }

    while (_playedSongs.contains(randomMusicFile)) {
      randomMusicFile = _getRandomMusicFile(availableSongs);
    }

    if(_playedSongs.length < _playedSongsMaxAmount) {
      _playedSongs.add(randomMusicFile);
      await _soundPlayer.playNewSong(randomMusicFile);

      return randomMusicFile;
    }
    else if(_playedSongs.length >= _playedSongsMaxAmount) {
      _playedSongs.removeAt(0);
      _playedSongs.add(randomMusicFile);
      await _soundPlayer.playNewSong(randomMusicFile);

      return randomMusicFile;
    }

    return randomMusicFile;
  }

  Future<void> selectAndPlaySong(MusicFile song) async {
    await _soundPlayer.playNewSong(song);
  }

  Future<void> resumeOrPauseSong() async {
    await _soundPlayer.resumeOrPauseSong();
  }

  Future<void> setLoopMode(bool enabled) async {
    await _soundPlayer.setLoopMode(enabled);
  }

  MusicFile _getRandomMusicFile(List<MusicFile> availableSongs) {
    return availableSongs[Random().nextInt(availableSongs.length)];
  }
}