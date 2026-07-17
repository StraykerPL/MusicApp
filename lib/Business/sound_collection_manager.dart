import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundCollectionManager {
  SoundCollectionManager({
    required SoundPlayer player,
    required DatabaseHelper databaseHelper,
    Random? random,
  })  : _soundPlayer = player,
        _databaseHelper = databaseHelper,
        _random = random ?? Random();

  final SoundPlayer _soundPlayer;
  final DatabaseHelper _databaseHelper;
  final Random _random;
  final List<MusicFile> _playedSongs = [];
  int _playedSongsMaxAmount = 0;

  StreamSubscription<PlaybackState> get getPlaybackStateSubscription =>
      _soundPlayer.getPlaybackStateSubscription();
  Stream<bool> get playingStream => _soundPlayer.playingStream;

  Future<MusicFile?> getRandomMusic(List<MusicFile> availableSongs) async {
    if (availableSongs.isEmpty) {
      return null;
    }

    MusicFile randomMusicFile = _getRandomMusicFile(availableSongs);
    _playedSongsMaxAmount = await _getPlayedSongsMaxAmount(availableSongs);

    if (_playedSongsMaxAmount == 0 || availableSongs.length == 1) {
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

      return randomMusicFile;
    } else if (_playedSongs.length >= _playedSongsMaxAmount) {
      _playedSongs.removeAt(0);
      _playedSongs.add(randomMusicFile);

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

  Future<void> stopPlayback() async {
    await _soundPlayer.stop();
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
    final snapshot = await _databaseHelper.getSettingsSnapshot();
    final savedMaxAmount = snapshot.playedSongsMaxAmount;
    final maxAllowedAmount = _getPlayedSongsMaxAllowed(availableSongs);
    final clampedMaxAmount = savedMaxAmount.clamp(0, maxAllowedAmount);

    if (clampedMaxAmount != savedMaxAmount) {
      await _databaseHelper.updatePlayedSongsMaxAmount(clampedMaxAmount);
    }

    return clampedMaxAmount;
  }

  int _getPlayedSongsMaxAllowed(List<MusicFile> availableSongs) {
    return availableSongs.length > 1 ? availableSongs.length - 1 : 0;
  }
}
