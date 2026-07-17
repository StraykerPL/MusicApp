import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

typedef AudioSessionProvider = Future<AudioSession> Function();
typedef NotificationSkipHandler = Future<void> Function();

final class DefaultAudioHandler extends BaseAudioHandler with QueueHandler {
  final AudioPlayer _player;
  final AudioSessionProvider _sessionProvider;
  NotificationSkipHandler? _skipToNextHandler;
  NotificationSkipHandler? _skipToPreviousHandler;
  bool _isPlaybackSessionActive = true;
  late AudioSession _session;
  late StreamSubscription<void> _noisyCheckStream;
  late StreamSubscription<AudioInterruptionEvent> _interruptEventStream;
  late StreamSubscription<AudioDevicesChangedEvent> _deviceChangeEventStream;
  bool get isLoopModeOn => _player.loopMode == LoopMode.all;
  Stream<bool> get playingStream => _player.playingStream;

  DefaultAudioHandler({
    AudioPlayer? player,
    AudioSessionProvider? sessionProvider,
  })  : _player = player ?? AudioPlayer(),
        _sessionProvider = sessionProvider ?? (() => AudioSession.instance) {
    _player.playbackEventStream.map(transformEvent).pipe(playbackState);
    _sessionProvider().then((session) {
      session.configure(const AudioSessionConfiguration.music());
      _session = session;

      _interruptEventStream =
          _session.interruptionEventStream.listen((event) async {
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

      _deviceChangeEventStream =
          session.devicesChangedEventStream.listen((event) async {
        await _player.pause();
      });
    });
  }

  PlaybackState transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: _isPlaybackSessionActive
          ? [
              _player.playing ? MediaControl.pause : MediaControl.play,
              MediaControl.stop,
              MediaControl.skipToPrevious,
              MediaControl.skipToNext,
            ]
          : const [],
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
  Future<void> play() async {
    if (_isPlaybackSessionActive) {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_isPlaybackSessionActive) {
      await _player.pause();
    }
  }

  @override
  Future<void> stop() async {
    _isPlaybackSessionActive = false;
    await _player.stop();
    await _session.setActive(false);
    mediaItem.add(null);
  }

  @override
  Future<void> skipToNext() async {
    if (_isPlaybackSessionActive) {
      await _skipToNextHandler?.call();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_isPlaybackSessionActive) {
      await _skipToPreviousHandler?.call();
    }
  }
  // End of widget handling code.

  void setNotificationSkipHandlers({
    NotificationSkipHandler? skipToNext,
    NotificationSkipHandler? skipToPrevious,
  }) {
    _skipToNextHandler = skipToNext;
    _skipToPreviousHandler = skipToPrevious;
  }

  Future<void> playNew(MediaItem item, String path) async {
    if (await _session.setActive(true)) {
      _isPlaybackSessionActive = true;
      try {
        mediaItem.add(item);
        await _player.setAudioSource(AudioSource.file(path, tag: item));
      } on PlayerInterruptedException catch (_) {}
      await _player.play();
    }
  }

  Future<void> resumeOrPauseSong() async {
    if (!_isPlaybackSessionActive) {
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> setLoopMode(bool enabled) async {
    await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _noisyCheckStream.cancel();
    await _interruptEventStream.cancel();
    await _deviceChangeEventStream.cancel();
  }
}
