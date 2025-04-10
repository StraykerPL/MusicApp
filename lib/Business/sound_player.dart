import 'dart:async';

import 'package:strayker_music/Business/default_audio_handler.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  late final DefaultAudioHandler _handler;
  MusicFile? currentSong;

  SoundPlayer({required DefaultAudioHandler handler}) {
    _handler = handler;
  }

  Stream<bool> isSoundPlaying() {
    return _handler.playbackState as Stream<bool>;
  }

  Future<void> playNewSong() async {
    await _handler.pause();
    
    _handler.playNew(currentSong!.mediaItemMetaData, currentSong!.filePath);
  }

  Future<void> resumeOrPauseSong() async {
    if(_handler.playbackState.value.playing) {
      await _handler.pause();
    }
    else {
      await _handler.play();
    }
  }
}