import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundCollectionManager {
  late final SoundPlayer _soundPlayer;
  late final DatabaseHelper _databaseHelper;
  late final Random _random;
  final List<MusicFile> _playedSongs = [];
  int _playedSongsMaxAmount = 0;

  StreamSubscription<PlaybackState> get getPlaybackStateSubscription =>
      _soundPlayer.getPlaybackStateSubscription();

  SoundCollectionManager({
    required SoundPlayer player,
    DatabaseHelper? databaseHelper,
    Random? random,
  }) {
    _soundPlayer = player;
    _databaseHelper = databaseHelper ?? DatabaseHelper();
    _random = random ?? Random();
  }

  Future<MusicFile> playRandomMusic(List<MusicFile> availableSongs) async {
    MusicFile randomMusicFile = _getRandomMusicFile(availableSongs);
    _playedSongsMaxAmount = await _getPlayedSongsMaxAmount(availableSongs);

    if (_playedSongsMaxAmount == 0 || availableSongs.length == 1) {
      await _soundPlayer.playNewSong(randomMusicFile);

      return randomMusicFile;
    }

    _playedSongs.removeWhere((song) => !availableSongs.contains(song));
    while (_playedSongs.length > _playedSongsMaxAmount) {
      _playedSongs.removeAt(0);
    }

    while (_playedSongs.contains(randomMusicFile)) {
      randomMusicFile = _getRandomMusicFile(availableSongs);
    }

    if (_playedSongs.length < _playedSongsMaxAmount) {
      _playedSongs.add(randomMusicFile);
      await _soundPlayer.playNewSong(randomMusicFile);

      return randomMusicFile;
    } else if (_playedSongs.length >= _playedSongsMaxAmount) {
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

  void setNotificationSkipHandlers({
    NotificationSkipHandler? skipToNext,
    NotificationSkipHandler? skipToPrevious,
  }) {
    _soundPlayer.setNotificationSkipHandlers(
      skipToNext: skipToNext,
      skipToPrevious: skipToPrevious,
    );
  }

  MusicFile _getRandomMusicFile(List<MusicFile> availableSongs) {
    return availableSongs[_random.nextInt(availableSongs.length)];
  }

  Future<int> _getPlayedSongsMaxAmount(List<MusicFile> availableSongs) async {
    final settings =
        await _databaseHelper.getAllData(DatabaseConstants.settingsTableName);
    for (final {"name": settingName, "value": settingValue} in settings) {
      if (settingName == DatabaseConstants.playedSongsMaxAmountTableValueName) {
        final savedMaxAmount = int.parse(settingValue);
        final maxAllowedAmount = _getPlayedSongsMaxAllowed(availableSongs);
        final clampedMaxAmount = savedMaxAmount.clamp(0, maxAllowedAmount);

        if (clampedMaxAmount != savedMaxAmount) {
          await _databaseHelper.updateDataByName(
            DatabaseConstants.settingsTableName,
            DatabaseConstants.playedSongsMaxAmountTableValueName,
            {"value": clampedMaxAmount.toString()},
          );
        }

        return clampedMaxAmount;
      }
    }

    return 0;
  }

  int _getPlayedSongsMaxAllowed(List<MusicFile> availableSongs) {
    return availableSongs.length > 1 ? availableSongs.length - 1 : 0;
  }
}
