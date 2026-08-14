import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';

import '../helpers/audio_test_helpers.dart';
import '../helpers/handler_harness.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class MockAudioSession extends Mock implements AudioSession {}

void main() {
  setUpAll(() {
    registerAudioTestFallbacks();
  });

  group('DefaultAudioHandler', () {
    test('factory waits for audio session configuration', () async {
      final player = MockAudioPlayer();
      final session = MockAudioSession();
      final configureCompleter = Completer<void>();
      final playbackEvents = StreamController<PlaybackEvent>.broadcast();
      final interruptions =
          StreamController<AudioInterruptionEvent>.broadcast();
      final noisy = StreamController<void>.broadcast();
      final devices = StreamController<AudioDevicesChangedEvent>.broadcast();
      addTearDown(playbackEvents.close);
      addTearDown(interruptions.close);
      addTearDown(noisy.close);
      addTearDown(devices.close);
      when(() => player.dispose()).thenAnswer((_) async {});
      when(() => player.playbackEventStream)
          .thenAnswer((_) => playbackEvents.stream);
      when(() => session.configure(any()))
          .thenAnswer((_) => configureCompleter.future);
      when(() => session.interruptionEventStream)
          .thenAnswer((_) => interruptions.stream);
      when(() => session.becomingNoisyEventStream)
          .thenAnswer((_) => noisy.stream);
      when(() => session.devicesChangedEventStream)
          .thenAnswer((_) => devices.stream);

      var completed = false;
      final future = DefaultAudioHandler.create(
        player: player,
        sessionProvider: () async => session,
      )..then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      configureCompleter.complete();
      final handler = await future;
      expect(completed, isTrue);
      await handler.dispose();
    });

    test('factory disposes its player when session setup fails', () async {
      final player = MockAudioPlayer();
      when(() => player.dispose()).thenAnswer((_) async {});

      await expectLater(
        DefaultAudioHandler.create(
          player: player,
          sessionProvider: () async => throw StateError('no session'),
        ),
        throwsStateError,
      );

      verify(() => player.dispose()).called(1);
    });

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

    test('stop ends playback, deactivates the session, and removes controls',
        () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);

      await harness.handler.stop();

      verify(() => harness.player.stop()).called(1);
      verify(() => harness.session.setActive(false)).called(1);
      expect(harness.handler.mediaItem.value, isNull);
      expect(
        harness.handler.transformEvent(PlaybackEvent()).controls,
        isEmpty,
      );
    });

    test('commands are ignored after playback has been stopped', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      var nextCalls = 0;
      var previousCalls = 0;
      harness.handler.setNotificationSkipHandlers(
        skipToNext: () async => nextCalls++,
        skipToPrevious: () async => previousCalls++,
      );

      await harness.handler.stop();
      clearInteractions(harness.player);
      await harness.handler.play();
      await harness.handler.pause();
      await harness.handler.resumeOrPauseSong();
      await harness.handler.skipToNext();
      await harness.handler.skipToPrevious();

      verifyNever(() => harness.player.play());
      verifyNever(() => harness.player.pause());
      expect(nextCalls, 0);
      expect(previousCalls, 0);
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

    test('stop invalidates a pending source request', () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      final sourceLoad = Completer<Duration?>();
      when(() => harness.player.setAudioSource(any()))
          .thenAnswer((_) => sourceLoad.future);

      final playFuture = harness.handler.playNew(
        const MediaItem(id: 'pending', title: 'Pending'),
        '/music/pending.mp3',
      );
      await untilCalled(() => harness.player.setAudioSource(any()));
      await harness.handler.stop();
      sourceLoad.complete(null);
      await playFuture;

      verifyNever(() => harness.player.play());
      expect(harness.handler.mediaItem.value, isNull);
    });

    test('interrupted older request never plays or clears the newer song',
        () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      final firstLoad = Completer<Duration?>();
      var sourceCalls = 0;
      when(() => harness.player.setAudioSource(any())).thenAnswer((_) {
        sourceCalls++;
        if (sourceCalls == 1) {
          return firstLoad.future;
        }
        return Future<Duration?>.value();
      });
      const first = MediaItem(id: 'first', title: 'First');
      const second = MediaItem(id: 'second', title: 'Second');

      final firstFuture = harness.handler.playNew(first, '/music/first.mp3');
      await untilCalled(() => harness.player.setAudioSource(any()));
      await harness.handler.playNew(second, '/music/second.mp3');
      firstLoad.completeError(PlayerInterruptedException('superseded'));
      await firstFuture;

      verify(() => harness.player.play()).called(1);
      expect(harness.handler.mediaItem.value, second);
    });

    test('source failures never play and propagate for the latest request',
        () async {
      final harness = await HandlerHarness.create();
      addTearDown(harness.close);
      final errors = <Object>[
        PlayerException(7, 'bad source'),
        const FileSystemException('missing file'),
      ];

      for (final error in errors) {
        when(() => harness.player.setAudioSource(any())).thenThrow(error);

        await expectLater(
          harness.handler.playNew(
            const MediaItem(id: 'broken', title: 'Broken'),
            '/music/broken.mp3',
          ),
          throwsA(same(error)),
        );
      }

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

    test('dispose is idempotent', () async {
      final harness = await HandlerHarness.create();

      await harness.handler.dispose();
      await harness.handler.dispose();

      verify(() => harness.player.dispose()).called(1);
      await harness.closeControllers();
    });
  });
}
