import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/sound_collection_manager.dart';
import 'package:strayker_music/Business/sound_player.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';

import '../helpers/fake_random.dart';
import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_database.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

class TrackingDatabaseHelper extends DatabaseHelper {
  int getSettingsSnapshotCalls = 0;

  @override
  Future<SettingsSnapshot> getSettingsSnapshot() async {
    getSettingsSnapshotCalls++;
    return SettingsSnapshot(
      playedSongsMaxAmount: 0,
      storageLocations: [],
    );
  }
}

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
      when(() => soundPlayer.stop()).thenAnswer((_) async {});
      when(() => soundPlayer.setLoopMode(any())).thenAnswer((_) async {});
      when(() => soundPlayer.getPlaybackStateSubscription())
          .thenAnswer((_) => playbackStateController.stream.listen((_) {}));
    });

    tearDown(() async {
      await playbackStateController.close();
      await fakeDatabase.close();
    });

    test('getRandomMusic selects a song when repeat history is disabled',
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

      final result = await manager.getRandomMusic(songs);

      expect(result, songs[1]);
    });

    test('uses the injected database helper for shuffle settings', () async {
      final trackingDatabaseHelper = TrackingDatabaseHelper();
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: trackingDatabaseHelper,
        random: FakeRandom([0]),
      );

      await manager.getRandomMusic([
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ]);

      expect(trackingDatabaseHelper.getSettingsSnapshotCalls, 1);
    });

    test('getRandomMusic with no songs is a no-op', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );

      final result = await manager.getRandomMusic(const []);

      expect(result, isNull);
      verifyNever(() => soundPlayer.playNewSong(any()));
    });

    test(
        'getRandomMusic skips already played songs when repeat history is enabled',
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

      final first = await manager.getRandomMusic(songs);
      final second = await manager.getRandomMusic(songs);

      expect(first, songs[0]);
      expect(second, songs[1]);
    });

    test(
        'getRandomMusic removes oldest remembered song when history reaches limit',
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

      await manager.getRandomMusic(songs);
      await manager.getRandomMusic(songs);
      final third = await manager.getRandomMusic(songs);
      final fourth = await manager.getRandomMusic(songs);

      expect(third, songs[2]);
      expect(fourth, songs[0]);
    });

    test(
        'getRandomMusic limits repeat history to one less than available songs',
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
          .updateDataByName('settings', 'playedSongsMaxAmount', {'value': '3'});

      await manager.getRandomMusic(songs);
      await manager.getRandomMusic(songs);
      final third = await manager.getRandomMusic(songs);
      final fourth = await manager.getRandomMusic(songs);
      final settings = await databaseHelper.getAllData('settings');
      final playedSongsMaxAmount = settings.firstWhere(
        (setting) => setting['name'] == 'playedSongsMaxAmount',
      );

      expect(third, songs[2]);
      expect(fourth, songs[0]);
      expect(playedSongsMaxAmount['value'], '2');
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

    test('stopPlayback delegates to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        databaseHelper: databaseHelper,
      );

      await manager.stopPlayback();

      verify(() => soundPlayer.stop()).called(1);
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
