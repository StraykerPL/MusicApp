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
    else {
      await _player.pause();
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _noisyCheckStream.cancel();
    await _interruptEventStream.cancel();
    await _deviceChangeEventStream.cancel();
  }
}