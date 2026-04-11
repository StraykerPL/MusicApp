import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Business/sound_player.dart';

import '../helpers/fake_random.dart';
import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_database.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

void main() {
  group('SoundCollectionManager', () {
    late FakeDatabase fakeDatabase;
    late DatabaseHelper databaseHelper;
    late SoundPlayer soundPlayer;
    late StreamController<PlaybackState> playbackStateController;

    setUp(() async {
      fakeDatabase = await FakeDatabase.seeded();
      databaseHelper =
          DatabaseHelper(databaseProvider: () async => fakeDatabase.database);
      playbackStateController = StreamController<PlaybackState>.broadcast();
      soundPlayer = MockSoundPlayer();
      when(() => soundPlayer.playNewSong(any())).thenAnswer((_) async {});
      when(() => soundPlayer.resumeOrPauseSong()).thenAnswer((_) async {});
      when(() => soundPlayer.setLoopMode(any())).thenAnswer((_) async {});
      when(() => soundPlayer.getPlaybackStateSubscription())
          .thenAnswer((_) => playbackStateController.stream.listen((_) {}));
    });

    tearDown(() async {
      await playbackStateController.close();
      await fakeDatabase.close();
    });

    test('playRandomMusic plays selected song when repeat history is disabled',
        () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
        random: FakeRandom([1]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];

      final result = await manager.playRandomMusic(songs);

      expect(result, songs[1]);
      verify(() => soundPlayer.playNewSong(songs[1])).called(1);
    });

    test(
        'playRandomMusic skips already played songs when repeat history is enabled',
        () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
        random: FakeRandom([0, 0, 1]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];
      await databaseHelper
          .updateDataByName('settings', 'playedSongsMaxAmount', {'value': '2'});

      final first = await manager.playRandomMusic(songs);
      final second = await manager.playRandomMusic(songs);

      expect(first, songs[0]);
      expect(second, songs[1]);
      verify(() => soundPlayer.playNewSong(songs[0])).called(1);
      verify(() => soundPlayer.playNewSong(songs[1])).called(1);
    });

    test(
        'playRandomMusic removes oldest remembered song when history reaches limit',
        () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
        random: FakeRandom([0, 1, 2, 0]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
        createSong('/music/gamma.mp3'),
      ];
      await databaseHelper
          .updateDataByName('settings', 'playedSongsMaxAmount', {'value': '2'});

      await manager.playRandomMusic(songs);
      await manager.playRandomMusic(songs);
      final third = await manager.playRandomMusic(songs);
      final fourth = await manager.playRandomMusic(songs);

      expect(third, songs[2]);
      expect(fourth, songs[0]);
      verify(() => soundPlayer.playNewSong(songs[0])).called(2);
      verify(() => soundPlayer.playNewSong(songs[1])).called(1);
      verify(() => soundPlayer.playNewSong(songs[2])).called(1);
    });

    test('selectAndPlaySong delegates selected song to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );
      final song = createSong('/music/alpha.mp3');

      await manager.selectAndPlaySong(song);

      verify(() => soundPlayer.playNewSong(song)).called(1);
    });

    test('resumeOrPauseSong delegates to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );

      await manager.resumeOrPauseSong();

      verify(() => soundPlayer.resumeOrPauseSong()).called(1);
    });

    test('setLoopMode delegates selected loop mode to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );

      await manager.setLoopMode(true);
      await manager.setLoopMode(false);

      verify(() => soundPlayer.setLoopMode(true)).called(1);
      verify(() => soundPlayer.setLoopMode(false)).called(1);
    });

    test('getPlaybackStateSubscription returns sound player subscription', () {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );

      final subscription = manager.getPlaybackStateSubscription;

      expect(subscription, isA<StreamSubscription>());
      verify(() => soundPlayer.getPlaybackStateSubscription()).called(1);
      addTearDown(subscription.cancel);
    });
  });
}
