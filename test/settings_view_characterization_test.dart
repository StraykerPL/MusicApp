import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:strayker_music/Business/database_helper.dart';
import 'package:strayker_music/Business/playlist_manager.dart';
import 'package:strayker_music/Constants/database_constants.dart';
import 'package:strayker_music/Models/music_file.dart';
import 'package:strayker_music/ViewModels/settings_view_model.dart';
import 'package:strayker_music/Widgets/settings.dart';

import 'helpers/music_file_test_helper.dart';
import 'mocks/fake_view_database_helpers.dart';

void main() {
  group('SettingsView current behavior', () {
    late FakeSettingsDatabaseHelper databaseHelper;
    late PlaylistManager playlistManager;
    late List<MusicFile> songs;

    setUp(() async {
      databaseHelper = FakeSettingsDatabaseHelper();
      songs = [
        createSong('/music/alpha.mp3'),
        createSong('/music/beta.mp3'),
        createSong('/music/gamma.mp3'),
      ];
      playlistManager = PlaylistManager(
        databaseHelper: databaseHelper,
        allSongs: songs,
      );
    });

    Widget testApp({required Widget home}) {
      return MultiProvider(
        providers: [
          Provider<List<MusicFile>>.value(value: songs),
          Provider<DatabaseHelper>.value(value: databaseHelper),
          ListenableProvider<PlaylistManager>.value(value: playlistManager),
          ChangeNotifierProvider(
            create: (_) => SettingsViewModel(
              databaseHelper: databaseHelper,
              playlistManager: playlistManager,
              loadedSongCount: songs.length,
            )..load(),
          ),
        ],
        child: MaterialApp(home: home),
      );
    }

    Future<String> savedMaximum() async {
      final settings = await databaseHelper.getAllData(
        DatabaseConstants.settingsTableName,
      );
      return settings
          .singleWhere(
            (row) =>
                row['name'] ==
                DatabaseConstants.playedSongsMaxAmountTableValueName,
          )['value']
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
      final readsBeforeCancel = databaseHelper.getSettingsSnapshotCalls;
      final writesBeforeCancel = databaseHelper.saveSettingsSnapshotCalls;

      final cancelButton = find.widgetWithText(ElevatedButton, 'Cancel');
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(await savedMaximum(), '0');
      expect(databaseHelper.getSettingsSnapshotCalls, readsBeforeCancel);
      expect(databaseHelper.saveSettingsSnapshotCalls, writesBeforeCancel);
    });

    testWidgets('Load Default persists immediately and keeps the screen open',
        (tester) async {
      await databaseHelper.updateDataByName(
        DatabaseConstants.settingsTableName,
        DatabaseConstants.playedSongsMaxAmountTableValueName,
        {'value': '2'},
      );
      await databaseHelper.cleanTable(
        DatabaseConstants.storagePathsTableName,
      );
      await databaseHelper.insertData(
        DatabaseConstants.storagePathsTableName,
        [
          {'name': '/music/custom'}
        ],
      );
      await tester.pumpWidget(testApp(home: const SettingsView()));
      await tester.pumpAndSettle();

      final defaultButton = find.widgetWithText(ElevatedButton, 'Load Default');
      await tester.ensureVisible(defaultButton);
      await tester.tap(defaultButton);
      await tester.pump(const Duration(milliseconds: 100));

      final paths = await databaseHelper.getAllData(
        DatabaseConstants.storagePathsTableName,
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.widgetWithText(TextField, '0'), findsOneWidget);
      expect(await savedMaximum(), '0');
      expect(paths, [
        {'id': 3, 'name': '/storage/emulated/0/Music'},
      ]);
    });

    testWidgets('failed Save displays the persistence error', (tester) async {
      databaseHelper.saveSettingsError = StateError('disk full');
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
      databaseHelper.saveSettingsError = StateError('read-only');
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
      final saveStarted = databaseHelper.pauseNextSave();
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

      databaseHelper.completeSave();
      await tester.pumpAndSettle();
    });
  });
}
