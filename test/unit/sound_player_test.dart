import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Business/sound_player.dart';

import '../helpers/audio_test_helpers.dart';
import '../helpers/handler_harness.dart';
import '../helpers/music_file_test_helper.dart';

void main() {
  setUpAll(() {
    registerAudioTestFallbacks();
  });

  group('SoundPlayer', () {
    late HandlerHarness handlerHarness;
    late SoundPlayer soundPlayer;

    setUp(() async {
      handlerHarness = await HandlerHarness.create();
      soundPlayer = SoundPlayer(handler: handlerHarness.handler);
    });

    tearDown(() async {
      await handlerHarness.close();
    });

    test('getPlaybackStateSubscription returns a playback state subscription',
        () {
      final subscription = soundPlayer.getPlaybackStateSubscription();

      expect(subscription, isA<StreamSubscription<PlaybackState>>());
      addTearDown(subscription.cancel);
    });

    test('playingStream exposes audio player playing changes', () async {
      final states = <bool>[];
      final subscription = soundPlayer.playingStream.listen(states.add);
      addTearDown(subscription.cancel);

      handlerHarness.playingStates.add(true);
      handlerHarness.playingStates.add(false);
      await Future<void>.delayed(Duration.zero);

      expect(states, [true, false]);
    });

    test('playNewSong loads and starts selected song', () async {
      final song = createSong('/music/alpha.mp3');

      await soundPlayer.playNewSong(song);

      verify(() => handlerHarness.session.setActive(true)).called(1);
      verify(() => handlerHarness.player.setAudioSource(any())).called(1);
      verify(() => handlerHarness.player.play()).called(1);
      expect(handlerHarness.handler.mediaItem.value, song.mediaItemMetaData);
    });

    test('playNewSong ignores null song', () async {
      await soundPlayer.playNewSong(null);

      verifyNever(() => handlerHarness.session.setActive(true));
      verifyNever(() => handlerHarness.player.setAudioSource(any()));
      verifyNever(() => handlerHarness.player.play());
      expect(handlerHarness.handler.mediaItem.value, isNull);
    });

    test('resumeOrPauseSong delegates pause when player is already playing',
        () async {
      await handlerHarness.close();
      handlerHarness = await HandlerHarness.create(isPlaying: true);
      soundPlayer = SoundPlayer(handler: handlerHarness.handler);

      await soundPlayer.resumeOrPauseSong();

      verify(() => handlerHarness.player.pause()).called(1);
      verifyNever(() => handlerHarness.player.play());
    });

    test('resumeOrPauseSong delegates play when player is not playing',
        () async {
      await handlerHarness.close();
      handlerHarness = await HandlerHarness.create(isPlaying: false);
      soundPlayer = SoundPlayer(handler: handlerHarness.handler);

      await soundPlayer.resumeOrPauseSong();

      verify(() => handlerHarness.player.play()).called(1);
      verifyNever(() => handlerHarness.player.pause());
    });

    test('stop delegates to the audio handler', () async {
      await soundPlayer.stop();

      verify(() => handlerHarness.player.stop()).called(1);
      verify(() => handlerHarness.session.setActive(false)).called(1);
    });

    test('setLoopMode delegates loop mode flag', () async {
      await soundPlayer.setLoopMode(true);
      await soundPlayer.setLoopMode(false);

      verify(() => handlerHarness.player.setLoopMode(LoopMode.one)).called(1);
      verify(() => handlerHarness.player.setLoopMode(LoopMode.off)).called(1);
    });

    test('setNotificationSkipHandlers delegates notification skip callbacks',
        () async {
      var nextCalls = 0;
      var previousCalls = 0;

      soundPlayer.setNotificationSkipHandlers(
        skipToNext: () async => nextCalls++,
        skipToPrevious: () async => previousCalls++,
      );
      await handlerHarness.handler.skipToNext();
      await handlerHarness.handler.skipToPrevious();

      expect(nextCalls, 1);
      expect(previousCalls, 1);
    });
  });
}
