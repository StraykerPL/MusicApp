import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:strayker_music/Models/music_file.dart';

final class SoundPlayer {
  final _player = AudioPlayer();
  late AudioSession _session;
  MusicFile? currentSong;
  late StreamSubscription<void> _noisyCheckStream;
  late StreamSubscription<AudioInterruptionEvent> _interruptEventStream;
  late StreamSubscription<AudioDevicesChangedEvent> _deviceChangeEventStream;

  SoundPlayer() {
    _player.setLoopMode(LoopMode.all);
    AudioSession.instance.then((session) {
      session.configure(const AudioSessionConfiguration.music());
      _session = session;

       _interruptEventStream = _session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _player.pause();
              break;

            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              await _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _player.play();
              break;

            case AudioInterruptionType.pause:
              await _player.play();
              
            case AudioInterruptionType.unknown:
              await _player.pause();
              break;
          }
        }
      });

      _noisyCheckStream = session.becomingNoisyEventStream.listen((_) async {
        await _player.pause();
      });

      _deviceChangeEventStream = session.devicesChangedEventStream.listen((event) async {
        await _player.pause();
      });
    });
  }

  Stream<bool> isSoundPlaying() {
    return _player.playingStream;
  }

  Future<void> playNewSong() async {
     await _player.pause();
    
    if(await _session.setActive(true)) {
      await _player.setAudioSource(
        AudioSource.file(currentSong!.filePath,tag: currentSong!.mediaItemMetaData,)
      );
      await _player.play();
    }
    else {
      await _player.pause();
    }
  }

  Future<void> resumeOrPauseSong() async {
    if(_player.playing) {
      await _player.pause();
    }
    else {
      await _player.play();
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _noisyCheckStream.cancel();
    await _interruptEventStream.cancel();
    await _deviceChangeEventStream.cancel();
  }
}