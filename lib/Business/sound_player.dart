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

  StreamSubscription<bool> isSoundPlaying() {
    return _player.playingStream.listen(null);
  }

  Future<void> playNewSong() async {
    _player.pause();
    var value = await _session.setActive(true);
    
    if(value) {
      _player.setAudioSource(
        AudioSource.file(
          currentSong!.filePath,
          tag: currentSong!.mediaItemMetaData,
        )
      ).whenComplete(() {
        _player.play();
      });
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
}