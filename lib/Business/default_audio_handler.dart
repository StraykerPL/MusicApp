import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

final class DefaultAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  late AudioSession _session;
  late StreamSubscription<void> _noisyCheckStream;
  late StreamSubscription<AudioInterruptionEvent> _interruptEventStream;
  late StreamSubscription<AudioDevicesChangedEvent> _deviceChangeEventStream;
  bool get isLoopModeOn => _player.loopMode == LoopMode.all;

  DefaultAudioHandler() {
    _player.setLoopMode(LoopMode.all);
    _player.playbackEventStream.map(transformEvent).pipe(playbackState);
    AudioSession.instance.then((session) {
      session.configure(const AudioSessionConfiguration.music());
      _session = session;

       _interruptEventStream = _session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _player.setVolume(_player.volume / 2);
              break;

            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              await _player.pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _player.setVolume(1.0);
              break;

            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
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

  PlaybackState transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
    );
  }

  // These overrides are not being used by code,
  // but they are necessary for notification panel's widget to work.
  @override
  Future<void> play() async => await _player.play();

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> stop() async => await _player.stop();

  Future<void> playNew(MediaItem item, String path) async {
    if(await _session.setActive(true)) {
      mediaItem.add(item);
      await _player.setAudioSource(
        AudioSource.file(path, tag: item)
      );
      await _player.play();
    }
  }

  Future<void> resumeOrPauseSong() async {
    if (_player.playing) {
      await _player.pause();
    }
    else {
      await _player.play();
    }
  }

  Future<void> setLoopMode(bool enabled) async {
    await _player.setLoopMode(enabled ? LoopMode.all : LoopMode.off);
  }

  Future<void> setLoop() async {
    if (_player.loopMode == LoopMode.all) {
      await _player.setLoopMode(LoopMode.off);
    }
    else {
      _player.setLoopMode(LoopMode.all);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _noisyCheckStream.cancel();
    await _interruptEventStream.cancel();
    await _deviceChangeEventStream.cancel();
  }
}