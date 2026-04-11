import 'dart:async';
import '../unit/default_audio_handler_test.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Business/default_audio_handler.dart';

class HandlerHarness {
  HandlerHarness({
    required this.handler,
    required this.player,
    required this.session,
    required this.playbackEvents,
    required this.interruptionEvents,
    required this.noisyEvents,
    required this.deviceEvents,
  });

  final DefaultAudioHandler handler;
  final MockAudioPlayer player;
  final MockAudioSession session;
  final StreamController<PlaybackEvent> playbackEvents;
  final StreamController<AudioInterruptionEvent> interruptionEvents;
  final StreamController<void> noisyEvents;
  final StreamController<AudioDevicesChangedEvent> deviceEvents;

  static Future<HandlerHarness> create({
    bool isPlaying = false,
    ProcessingState processingState = ProcessingState.ready,
    LoopMode loopMode = LoopMode.off,
    double volume = 1.0,
    bool sessionActive = true,
  }) async {
    final player = MockAudioPlayer();
    final session = MockAudioSession();
    final playbackEvents = StreamController<PlaybackEvent>.broadcast();
    final interruptionEvents = StreamController<AudioInterruptionEvent>.broadcast();
    final noisyEvents = StreamController<void>.broadcast();
    final deviceEvents = StreamController<AudioDevicesChangedEvent>.broadcast();

    when(() => player.playbackEventStream).thenAnswer((_) => playbackEvents.stream);
    when(() => player.playing).thenReturn(isPlaying);
    when(() => player.processingState).thenReturn(processingState);
    when(() => player.loopMode).thenReturn(loopMode);
    when(() => player.volume).thenReturn(volume);
    when(() => player.play()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.setLoopMode(any())).thenAnswer((_) async {});
    when(() => player.setAudioSource(any())).thenAnswer((_) async => null);

    when(() => session.configure(any())).thenAnswer((_) async {});
    when(() => session.setActive(any())).thenAnswer((_) async => sessionActive);
    when(() => session.interruptionEventStream).thenAnswer((_) => interruptionEvents.stream);
    when(() => session.becomingNoisyEventStream).thenAnswer((_) => noisyEvents.stream);
    when(() => session.devicesChangedEventStream).thenAnswer((_) => deviceEvents.stream);

    final handler = DefaultAudioHandler(
      player: player,
      sessionProvider: () async => session,
    );

    await Future<void>.delayed(Duration.zero);

    return HandlerHarness(
      handler: handler,
      player: player,
      session: session,
      playbackEvents: playbackEvents,
      interruptionEvents: interruptionEvents,
      noisyEvents: noisyEvents,
      deviceEvents: deviceEvents,
    );
  }

  Future<void> close() async {
    await handler.dispose();
    await closeControllers();
  }

  Future<void> closeControllers() async {
    await playbackEvents.close();
    await interruptionEvents.close();
    await noisyEvents.close();
    await deviceEvents.close();
  }
}
