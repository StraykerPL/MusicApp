import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Services/playlist_manager.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/Models/settings_snapshot.dart';
import 'package:strayker_music/Repositories/settings_snapshot_repository.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';
import 'package:strayker_music/Widgets/settings.dart';

import 'helpers/music_file_test_helper.dart';
import 'mocks/fake_view_database_helpers.dart';

void main() {
  group('SettingsView current behavior', () {
    late FakeSettingsSnapshotRepository settingsSnapshotRepository;
    late FakePlaylistRepository playlistRepository;
    late PlaylistManager playlistManager;
    late List<MusicFile> songs;

    setUp(() async {
      settingsSnapshotRepository = FakeSettingsSnapshotRepository();
      playlistRepository = FakePlaylistRepository();
      songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
        createSong('/music/gamma.mp3'),
      ];
      playlistManager = PlaylistManager(
        playlistRepository: playlistRepository,
        allSongs: songs,
      );
    });

    Widget testApp({required Widget home}) {
      return MultiProvider(
        providers: [
          Provider<List<MusicFile>>.value(value: songs),
          Provider<SettingsSnapshotRepository>.value(
            value: settingsSnapshotRepository,
          ),
          ListenableProvider<PlaylistManager>.value(value: playlistManager),
          ChangeNotifierProvider(
            create: (_) => SettingsViewModel(
              settingsSnapshotRepository: settingsSnapshotRepository,
              playlistManager: playlistManager,
              loadedSongCount: songs.length,
            )..load(),
          ),
        ],
        child: MaterialApp(home: home),
      );
    }

    Future<String> savedMaximum() async {
      return settingsSnapshotRepository.snapshot.playedSongsMaxAmount
          .toString();
    }

    testWidgets('Save clamps and persists without closing the screen',
        (tester) async {
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '999');
      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
      expect(await savedMaximum(), '2');
    });

    testWidgets('Cancel leaves unsaved data unchanged and closes the screen',
        (tester) async {
      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsView(),
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '2');
      final readsBeforeCancel = settingsSnapshotRepository.getCalls;
      final writesBeforeCancel = settingsSnapshotRepository.saveCalls;

      final cancelButton = find.widgetWithText(ElevatedButton, 'Cancel');
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(await savedMaximum(), '0');
      expect(settingsSnapshotRepository.getCalls, readsBeforeCancel);
      expect(settingsSnapshotRepository.saveCalls, writesBeforeCancel);
    });

    testWidgets('Load Default persists immediately and keeps the screen open',
        (tester) async {
      settingsSnapshotRepository.snapshot = SettingsSnapshot(
        playedSongsMaxAmount: 2,
        storageLocations: ['/music/custom'],
      );
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final defaultButton = find.widgetWithText(ElevatedButton, 'Load Default');
      await tester.ensureVisible(defaultButton);
      await tester.tap(defaultButton);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0'), findsOneWidget);
      expect(await savedMaximum(), '0');
      expect(
        settingsSnapshotRepository.snapshot.storageLocations,
        ['/storage/emulated/0/Music'],
      );
    });

    testWidgets('failed Save displays the persistence error', (tester) async {
      settingsSnapshotRepository.saveError = StateError('disk full');
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to save settings: Bad state: disk full'),
        findsOneWidget,
      );
    });

    testWidgets('failed Load Default displays the persistence error',
        (tester) async {
      settingsSnapshotRepository.saveError = StateError('read-only');
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final defaultButton = find.widgetWithText(ElevatedButton, 'Load Default');
      await tester.ensureVisible(defaultButton);
      await tester.tap(defaultButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Failed to restore defaults: Bad state: read-only',
        ),
        findsOneWidget,
      );
    });

    testWidgets('all persistence buttons are disabled while saving',
        (tester) async {
      final saveStarted = settingsSnapshotRepository.pauseNextSave();
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final saveFinder = find.widgetWithText(ElevatedButton, 'Save');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await saveStarted;
      await tester.pump();

      for (final label in ['Save', 'Cancel', 'Load Default']) {
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, label),
        );
        expect(button.onPressed, isNull, reason: '$label should be disabled');
      }

      settingsSnapshotRepository.completeSave();
      await tester.pumpAndSettle();
    });
  });
}
