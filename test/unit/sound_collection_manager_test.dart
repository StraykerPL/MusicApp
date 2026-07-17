import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';

import '../helpers/fake_random.dart';
import '../helpers/music_file_test_helper.dart';
import '../mocks/fake_view_database_helpers.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

void main() {
  group('SoundCollectionManager', () {
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late SoundPlayer soundPlayer;
    late StreamController<PlaybackState> playbackStateController;

    setUp(() {
      settingsSnapshotRepository = FakeSettingsSnapshotRepository();
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
    });

    test('getRandomMusic selects a song when repeat history is disabled',
        () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
        random: FakeRandom([1]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];

      final result = await manager.getRandomMusic(songs);

      expect(result, songs[1]);
    });

    test('uses the injected settings repository for shuffle settings',
        () async {
      final trackingRepository = FakeSettingsSnapshotRepository();
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: trackingRepository,
        random: FakeRandom([0]),
      );

      await manager.getRandomMusic([
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ]);

      expect(trackingRepository.getCalls, 1);
    });

    test('getRandomMusic with no songs is a no-op', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
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
        settingsSnapshotRepository: settingsSnapshotRepository,
        random: FakeRandom([0, 0, 1]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];
      settingsSnapshotRepository.snapshot = SettingsSnapshot(
        playedSongsMaxAmount: 2,
        storageLocations: [],
      );

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
        settingsSnapshotRepository: settingsSnapshotRepository,
        random: FakeRandom([0, 1, 2, 0]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
        createSong('/music/gamma.mp3'),
      ];
      settingsSnapshotRepository.snapshot = SettingsSnapshot(
        playedSongsMaxAmount: 2,
        storageLocations: [],
      );

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
        settingsSnapshotRepository: settingsSnapshotRepository,
        random: FakeRandom([0, 1, 2, 0]),
      );
      final songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
        createSong('/music/gamma.mp3'),
      ];
      settingsSnapshotRepository.snapshot = SettingsSnapshot(
        playedSongsMaxAmount: 3,
        storageLocations: [],
      );

      await manager.getRandomMusic(songs);
      await manager.getRandomMusic(songs);
      final third = await manager.getRandomMusic(songs);
      final fourth = await manager.getRandomMusic(songs);

      expect(third, songs[2]);
      expect(fourth, songs[0]);
      expect(settingsSnapshotRepository.snapshot.playedSongsMaxAmount, 2);
    });

    test('selectAndPlaySong delegates selected song to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );
      final song = createSong('/music/alpha.mp3');

      await manager.selectAndPlaySong(song);

      verify(() => soundPlayer.playNewSong(song)).called(1);
    });

    test('resumeOrPauseSong delegates to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );

      await manager.resumeOrPauseSong();

      verify(() => soundPlayer.resumeOrPauseSong()).called(1);
    });

    test('stopPlayback delegates to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );

      await manager.stopPlayback();

      verify(() => soundPlayer.stop()).called(1);
    });

    test('setLoopMode delegates selected loop mode to sound player', () async {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );

      await manager.setLoopMode(true);
      await manager.setLoopMode(false);

      verify(() => soundPlayer.setLoopMode(true)).called(1);
      verify(() => soundPlayer.setLoopMode(false)).called(1);
    });

    test('getPlaybackStateSubscription returns sound player subscription', () {
      final manager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );

      final subscription = manager.getPlaybackStateSubscription;

      expect(subscription, isA<StreamSubscription>());
      verify(() => soundPlayer.getPlaybackStateSubscription()).called(1);
      addTearDown(subscription.cancel);
    });
  });
}
