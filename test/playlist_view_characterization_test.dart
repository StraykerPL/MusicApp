import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Services/default_audio_handler.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Services/sound_collection_manager.dart';
import 'package:strayker_music/Services/sound_player.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/ViewModels/playlist_view_model.dart';
import 'package:strayker_music/Widgets/playlist_view.dart';

import 'helpers/music_file_test_helper.dart';
import 'mocks/fake_view_database_helpers.dart';

class MockSoundPlayer extends Mock implements SoundPlayer {}

class RecreatingPlaylistHost extends StatefulWidget {
  const RecreatingPlaylistHost({super.key});

  @override
  State<RecreatingPlaylistHost> createState() => _RecreatingPlaylistHostState();
}

class _RecreatingPlaylistHostState extends State<RecreatingPlaylistHost> {
  bool showPlaylist = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: showPlaylist ? const PlaylistView() : const SizedBox.shrink(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => showPlaylist = !showPlaylist),
        child: const Icon(Icons.swap_horiz),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaylistView current behavior', () {
    late FakePlaylistRepository playlistRepository;
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late PlaylistManager playlistManager;
    late MockSoundPlayer soundPlayer;
    late SoundCollectionManager soundCollectionManager;
    late PlaylistViewModel playlistViewModel;
    late StreamController<PlaybackState> playbackStates;
    late StreamController<bool> playingStates;
    late void Function(bool value) emitPlayingState;
    late List<MusicFile> songs;
    NotificationSkipHandler? skipToNext;
    NotificationSkipHandler? skipToPrevious;

    setUp(() async {
      PackageInfo.setMockInitialValues(
        appName: 'Strayker Music',
        packageName: 'strayker_music',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      playlistRepository = FakePlaylistRepository();
      settingsSnapshotRepository = FakeSettingsSnapshotRepository();
      songs = [
        createSong('/music/gamma.mp3'),
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
      ];
      playlistManager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: songs,
      );
      soundPlayer = MockSoundPlayer();
      soundCollectionManager = SoundCollectionManager(
        player: soundPlayer,
        settingsSnapshotRepository: settingsSnapshotRepository,
      );
      playlistViewModel = PlaylistViewModel(
        playlistManager: playlistManager,
        soundCollectionManager: soundCollectionManager,
      );
      playbackStates = StreamController<PlaybackState>.broadcast();
      var latestPlayingState = false;
      playingStates = StreamController<bool>.broadcast(
        onListen: () => playingStates.add(latestPlayingState),
      );
      emitPlayingState = (value) {
        latestPlayingState = value;
        playingStates.add(value);
      };

      when(() => soundPlayer.getPlaybackStateSubscription()).thenAnswer(
        (_) => playbackStates.stream.listen((_) {}),
      );
      when(() => soundPlayer.playingStream)
          .thenAnswer((_) => playingStates.stream);
      when(() => soundPlayer.setLoopMode(any())).thenAnswer((_) async {});
      when(() => soundPlayer.playNewSong(any())).thenAnswer((_) async {});
      when(() => soundPlayer.resumeOrPauseSong()).thenAnswer((_) async {});
      when(() => soundPlayer.stop()).thenAnswer((_) async {});
      when(
        () => soundPlayer.setNotificationSkipHandlers(
          skipToNext: any(named: 'skipToNext'),
          skipToPrevious: any(named: 'skipToPrevious'),
        ),
      ).thenAnswer((invocation) {
        skipToNext =
            invocation.namedArguments[#skipToNext] as NotificationSkipHandler?;
        skipToPrevious = invocation.namedArguments[#skipToPrevious]
            as NotificationSkipHandler?;
      });
      when(() => soundPlayer.setNotificationSkipHandlers()).thenAnswer((_) {});
    });

    tearDown(() async {
      playlistViewModel.dispose();
      await playbackStates.close();
      await playingStates.close();
    });

    Future<void> pumpPlaylistView(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<List<MusicFile>>.value(value: songs),
            ListenableProvider<PlaylistManager>.value(value: playlistManager),
            Provider<SoundPlayer>.value(value: soundPlayer),
            Provider<SoundCollectionManager>.value(
              value: soundCollectionManager,
            ),
            ChangeNotifierProvider<PlaylistViewModel>.value(
              value: playlistViewModel..initialize(),
            ),
          ],
          child: const MaterialApp(home: PlaylistView()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('search is case-insensitive and toggling it clears the query',
        (tester) async {
      await pumpPlaylistView(tester);

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('gamma'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'LPH');
      await tester.pump();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);
      expect(find.text('gamma'), findsNothing);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(find.widgetWithText(TextField, ''), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('gamma'), findsOneWidget);
    });

    testWidgets('playlist selection changes the title and displayed songs',
        (tester) async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      await playlistRepository.addSong(
        playlistId,
        '/music/beta.mp3',
      );
      await playlistManager.switchToPlaylist('Focus');
      await pumpPlaylistView(tester);

      expect(find.widgetWithText(AppBar, 'Focus'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('alpha'), findsNothing);
      expect(find.text('gamma'), findsNothing);
    });

    testWidgets('drawer observes playlist changes from shared state',
        (tester) async {
      await pumpPlaylistView(tester);

      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(find.text('Focus'), findsNothing);

      await playlistManager.createPlaylist('Focus');
      await tester.pump();

      expect(find.text('Focus'), findsOneWidget);
    });

    testWidgets(
        'completed playback advances and wraps in a named playlist when looping is off',
        (tester) async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      for (final song in songs) {
        await playlistRepository.addSong(playlistId, song.filePath);
      }
      await playlistManager.switchToPlaylist('Focus');
      await pumpPlaylistView(tester);
      await tester.tap(find.text('gamma'));
      await tester.pump();
      clearInteractions(soundPlayer);

      playbackStates.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
      await tester.pump();

      verify(() => soundPlayer.playNewSong(songs.first)).called(1);
      expect(find.byIcon(Icons.music_note), findsNWidgets(2));
    });

    testWidgets('notification next and previous use the playlist and wrap',
        (tester) async {
      final playlistId = (await playlistRepository.create('Focus')).id;
      for (final song in songs) {
        await playlistRepository.addSong(playlistId, song.filePath);
      }
      await playlistManager.switchToPlaylist('Focus');
      await pumpPlaylistView(tester);
      await tester.tap(find.text('gamma'));
      await tester.pump();
      clearInteractions(soundPlayer);

      await skipToNext!();
      await tester.pump();
      await skipToPrevious!();
      await tester.pump();

      verify(() => soundPlayer.playNewSong(songs.first)).called(1);
      verify(() => soundPlayer.playNewSong(songs.last)).called(1);
    });

    testWidgets('player stream keeps notification pause in sync with the UI',
        (tester) async {
      await pumpPlaylistView(tester);
      await tester.tap(find.text('alpha'));
      await tester.pump();

      emitPlayingState(true);
      await tester.pump();
      expect(find.byIcon(Icons.pause), findsOneWidget);

      emitPlayingState(false);
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shuffle is disabled when the current playlist is empty',
        (tester) async {
      await playlistRepository.create('Empty');
      await playlistManager.switchToPlaylist('Empty');
      await pumpPlaylistView(tester);

      final shuffleButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.byIcon(Icons.shuffle),
          matching: find.byType(ElevatedButton),
        ),
      );

      expect(shuffleButton.onPressed, isNull);
    });

    testWidgets(
        'recreating PlaylistView preserves playback and registers listeners once',
        (tester) async {
      await playlistViewModel.initialize();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<List<MusicFile>>.value(value: songs),
            ListenableProvider<PlaylistManager>.value(value: playlistManager),
            Provider<SoundPlayer>.value(value: soundPlayer),
            Provider<SoundCollectionManager>.value(
              value: soundCollectionManager,
            ),
            ChangeNotifierProvider<PlaylistViewModel>.value(
              value: playlistViewModel,
            ),
          ],
          child: const MaterialApp(home: RecreatingPlaylistHost()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('alpha'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      expect(find.byType(PlaylistView), findsNothing);

      emitPlayingState(true);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pumpAndSettle();

      expect(find.byType(PlaylistView), findsOneWidget);
      expect(playlistViewModel.currentSong, playlistViewModel.songs.first);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      verify(() => soundPlayer.getPlaybackStateSubscription()).called(1);
      verify(
        () => soundPlayer.setNotificationSkipHandlers(
          skipToNext: any(named: 'skipToNext'),
          skipToPrevious: any(named: 'skipToPrevious'),
        ),
      ).called(1);
    });
  });
}
