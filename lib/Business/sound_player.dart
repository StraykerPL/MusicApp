import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  late final DefaultAudioHandler _handler;

  SoundPlayer({required DefaultAudioHandler handler}) {
    _handler = handler;
  }

  StreamSubscription<PlaybackState> getPlaybackStateSubscription() {
    return _handler.playbackState.listen((state) {});
  }

  Future<void> playNewSong(MusicFile? newSong) async {
    if (newSong != null)
    {
      await _handler.playNew(newSong.mediaItemMetaData, newSong.filePath);
    }
  }

  Future<void> resumeOrPauseSong() async {
    await _handler.resumeOrPauseSong();
  }

  bool get isLoopModeOn => _handler.isLoopModeOn;

  Future<void> setLoop() async {
    await _handler.setLoop();
  }

  Future<void> setLoopMode(bool enabled) async {
    await _handler.setLoop();
  }
}