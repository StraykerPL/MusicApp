import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

typedef AudioSessionProvider = Future<AudioSession> Function();
typedef NotificationSkipHandler = Future<void> Function();

final class DefaultAudioHandler extends BaseAudioHandler with QueueHandler {
  DefaultAudioHandler._({
    required AudioPlayer player,
    required AudioSession session,
  })  : _player = player,
        _session = session {
    _interruptionSubscription =
        _session.interruptionEventStream.listen(_onInterruption);
    _noisySubscription = _session.becomingNoisyEventStream
        .listen((void event) => _pauseSafely());
    _deviceSubscription = _session.devicesChangedEventStream.listen(
      (AudioDevicesChangedEvent event) => _pauseSafely(),
    );
    _player.playbackEventStream.map(transformEvent).pipe(playbackState);
  }

  final AudioPlayer _player;
  final AudioSession _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;
  StreamSubscription<AudioDevicesChangedEvent>? _deviceSubscription;
  NotificationSkipHandler? _skipToNextHandler;
  NotificationSkipHandler? _skipToPreviousHandler;
  bool _isPlaybackSessionActive = true;
  bool _disposed = false;
  int _playRequest = 0;

  bool get isLoopModeOn => _player.loopMode == LoopMode.all;
  Stream<bool> get playingStream => _player.playingStream;

  static Future<DefaultAudioHandler> create({
    AudioPlayer? player,
    AudioSessionProvider? sessionProvider,
  }) async {
    final AudioPlayer resolvedPlayer = player ?? AudioPlayer();
    final AudioSessionProvider resolvedSessionProvider =
        sessionProvider ?? (() => AudioSession.instance);

    try {
      final AudioSession session = await resolvedSessionProvider();
      await session.configure(const AudioSessionConfiguration.music());

      return DefaultAudioHandler._(
        player: resolvedPlayer,
        session: session,
      );
    } on Object catch (error, stackTrace) {
      await resolvedPlayer.dispose();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  PlaybackState transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: _isPlaybackSessionActive
          ? <MediaControl>[
              _player.playing ? MediaControl.pause : MediaControl.play,
              MediaControl.stop,
              MediaControl.skipToPrevious,
              MediaControl.skipToNext,
            ]
          : const <MediaControl>[],
      processingState: const <ProcessingState, AudioProcessingState>{
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
  Future<void> play() async {
    if (_isPlaybackSessionActive && !_disposed) {
      await _player.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_isPlaybackSessionActive && !_disposed) {
      await _player.pause();
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }
    ++_playRequest;
    _isPlaybackSessionActive = false;
    await _player.stop();
    await _session.setActive(false);
    mediaItem.add(null);
  }

  @override
  Future<void> skipToNext() async {
    if (_isPlaybackSessionActive && !_disposed) {
      await _skipToNextHandler?.call();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_isPlaybackSessionActive && !_disposed) {
      await _skipToPreviousHandler?.call();
    }
  }

  void setNotificationSkipHandlers({
    NotificationSkipHandler? skipToNext,
    NotificationSkipHandler? skipToPrevious,
  }) {
    _skipToNextHandler = skipToNext;
    _skipToPreviousHandler = skipToPrevious;
  }

  Future<void> playNew(MediaItem item, String path) async {
    if (_disposed) {
      return;
    }

    final int request = ++_playRequest;
    try {
      final bool sessionActivated = await _session.setActive(true);
      if (!sessionActivated || request != _playRequest || _disposed) {
        return;
      }

      final AudioSource source = AudioSource.file(path, tag: item);
      await _player.setAudioSource(source);
      if (request != _playRequest || _disposed) {
        return;
      }

      _isPlaybackSessionActive = true;
      mediaItem.add(item);
      await _player.play();
    } on PlayerInterruptedException {
      return;
    } on PlayerException catch (error, stackTrace) {
      if (request == _playRequest && !_disposed) {
        mediaItem.add(null);
        _isPlaybackSessionActive = false;
      }

      Error.throwWithStackTrace(error, stackTrace);
    } on Object catch (error, stackTrace) {
      if (request == _playRequest && !_disposed) {
        mediaItem.add(null);
        _isPlaybackSessionActive = false;
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> resumeOrPauseSong() async {
    if (!_isPlaybackSessionActive || _disposed) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> setLoopMode(bool enabled) async {
    if (!_disposed) {
      await _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
    }
  }

  Future<void> _onInterruption(AudioInterruptionEvent event) async {
    if (_disposed) {
      return;
    }
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          await _player.setVolume(_player.volume / 2);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          await _pauseSafely();
          break;
      }
    } else if (event.type == AudioInterruptionType.duck) {
      await _player.setVolume(1.0);
    }
  }

  Future<void> _pauseSafely() async {
    if (!_disposed) {
      await _player.pause();
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    ++_playRequest;
    _skipToNextHandler = null;
    _skipToPreviousHandler = null;

    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _deviceSubscription?.cancel();
    await _player.dispose();

    _interruptionSubscription = null;
    _noisySubscription = null;
    _deviceSubscription = null;
  }
}
