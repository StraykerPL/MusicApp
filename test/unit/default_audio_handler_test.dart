import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/audio_test_helpers.dart';
import '../helpers/handler_harness.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockAudioSession extends Mock implements AudioSession {}

void main() {
  setUpAll(() {
    registerAudioTestFallbacks();
  });

  group('DefaultAudioHandler', () {
    test('transformEvent exposes play control when player is idle and paused',
        () async {
      final harness = await HandlerHarness.create(
        isPlaying: false,
        processingState: ProcessingState.idle,
      );
      addTearDown(harness.close);

      final state = harness.handler.transformEvent(PlaybackEvent());

      expect(state.playing, isFalse);
      expect(state.processingState, AudioProcessingState.idle);
      expect(state.controls, [
        MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToPrevious,
        MediaControl.skipToNext,
      ]);
    });

    test('play delegates to audio player', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      await harness.handler.play();

      verify(() => harness.player.play()).called(1);
    });

    test('pause delegates to audio player', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      await harness.handler.pause();

      verify(() => harness.player.pause()).called(1);
    });

    test('stop delegates to audio player', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      await harness.handler.stop();

      verify(() => harness.player.stop()).called(1);
    });

    test('skipToNext delegates to notification skip handler', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      var calls = 0;
      harness.handler.setNotificationSkipHandlers(
        skipToNext: () async => calls++,
      );

      await harness.handler.skipToNext();

      expect(calls, 1);
      verifyNever(() => harness.player.play());
    });

    test('skipToPrevious delegates to notification skip handler', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      var calls = 0;
      harness.handler.setNotificationSkipHandlers(
        skipToPrevious: () async => calls++,
      );

      await harness.handler.skipToPrevious();

      expect(calls, 1);
      verifyNever(() => harness.player.play());
    });

    test(
        'playNew activates session, updates media item, loads source, and starts playback',
        () async {
      final harness = await HandlerHarness.create(sessionActive: true);
      addTearDown(harness.close);
      const item = MediaItem(id: 'song-1', title: 'Song 1');

      await harness.handler.playNew(item, '/music/song-1.mp3');

      verify(() => harness.session.setActive(true)).called(1);
      verify(() => harness.player.setAudioSource(any())).called(1);
      verify(() => harness.player.play()).called(1);
      expect(harness.handler.mediaItem.value, item);
    });

    test('playNew does nothing when session cannot be activated', () async {
      final harness = await HandlerHarness.create(sessionActive: false);
      addTearDown(harness.close);
      const item = MediaItem(id: 'song-1', title: 'Song 1');

      await harness.handler.playNew(item, '/music/song-1.mp3');

      verify(() => harness.session.setActive(true)).called(1);
      verifyNever(() => harness.player.setAudioSource(any()));
      verifyNever(() => harness.player.play());
      expect(harness.handler.mediaItem.value, isNull);
    });

    test('resumeOrPauseSong pauses when player is already playing', () async {
      final harness = await HandlerHarness.create(isPlaying: true);
      addTearDown(harness.close);

      await harness.handler.resumeOrPauseSong();

      verify(() => harness.player.pause()).called(1);
      verifyNever(() => harness.player.play());
    });

    test('resumeOrPauseSong plays when player is not playing', () async {
      final harness = await HandlerHarness.create(isPlaying: false);
      addTearDown(harness.close);

      await harness.handler.resumeOrPauseSong();

      verify(() => harness.player.play()).called(1);
      verifyNever(() => harness.player.pause());
    });

    test('setLoopMode toggles between one and off', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      await harness.handler.setLoopMode(true);
      await harness.handler.setLoopMode(false);

      verify(() => harness.player.setLoopMode(LoopMode.one)).called(1);
      verify(() => harness.player.setLoopMode(LoopMode.off)).called(1);
    });

    test('becoming noisy event pauses playback', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      harness.noisyEvents.add(null);
      await Future<void>.delayed(Duration.zero);

      verify(() => harness.player.pause()).called(1);
    });

    test('duck interruption lowers and restores volume', () async {
      final harness = await HandlerHarness.create(volume: 0.8);
      addTearDown(harness.close);

      harness.interruptionEvents.add(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      await Future<void>.delayed(Duration.zero);
      harness.interruptionEvents.add(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => harness.player.setVolume(0.4)).called(1);
      verify(() => harness.player.setVolume(1.0)).called(1);
    });

    test('dispose releases player and unsubscribes from session streams',
        () async {
      final harness = await HandlerHarness.create();

      await harness.handler.dispose();
      harness.noisyEvents.add(null);
      harness.deviceEvents.add(AudioDevicesChangedEvent());
      harness.interruptionEvents.add(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => harness.player.dispose()).called(1);
      verifyNever(() => harness.player.pause());
      await harness.closeControllers();
    });
  });
}
