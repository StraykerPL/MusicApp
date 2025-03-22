import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  late AudioSession _session;
  MusicFile? currentSong;

  SoundPlayer() {
    _player.setLoopMode(LoopMode.all);
    AudioSession.instance.then((completedSession) {
      completedSession.configure(const AudioSessionConfiguration.music());
      _session = completedSession;

      return completedSession;
    });
  }

  Stream<bool> isSoundPlaying() {
    return _player.playingStream;
  }

  Future<void> playNewSong() async {
    _player.pause();
    
    // TODO: Add handling for audio session's states (Audio Session package).
    if(await _session.setActive(true)) {
      _player.setAudioSource(
        AudioSource.file(
          currentSong!.filePath,
          tag: currentSong!.mediaItemMetaData,
        )
      ).whenComplete(() {
        _player.play();
      });
    }
    else {
      _player.pause();
    }
  }

  void resumeOrPauseSong() {
    if(_player.playing) {
      _player.pause();
    }
    else {
      _player.play();
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}